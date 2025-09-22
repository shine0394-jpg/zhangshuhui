"""Utility functions for audio processing workflows.

This module provides a collection of helpers that cover common tasks such as
sample-rate conversion, loudness normalisation, lightweight noise reduction,
and diagnostic analytics (spectral analysis, perceptual quality heuristics).

The implementations favour clarity and rely only on widely available
scientific Python packages already listed in the project requirements.
"""
from __future__ import annotations

from dataclasses import dataclass
from math import gcd
from typing import Optional, Tuple

import numpy as np
from numpy.typing import ArrayLike, NDArray
from scipy import signal

_EPS = np.finfo(np.float32).eps


def _to_float32(audio: ArrayLike) -> NDArray[np.float32]:
    """Convert arbitrary array-likes to a contiguous float32 numpy array."""
    array = np.asarray(audio, dtype=np.float32)
    if array.ndim == 1:
        return np.ascontiguousarray(array)
    if array.ndim == 2:
        return np.ascontiguousarray(array)
    raise ValueError("Audio array must be 1D (mono) or 2D (multi-channel).")


def convert_format(
    audio: ArrayLike,
    source_rate: int,
    target_rate: int,
    source_channels: int = 1,
    target_channels: int = 1,
    dtype: np.dtype | type | str = np.float32,
) -> NDArray:
    """Convert audio arrays between sample rates, channel layouts, and dtypes.

    Args:
        audio: Input audio samples. The array can be mono (shape ``[N]``) or
            multi-channel (shape ``[N, C]``).
        source_rate: Sample rate of ``audio`` in Hz.
        target_rate: Desired sample rate in Hz.
        source_channels: Number of channels in the input representation.
        target_channels: Desired number of channels in the output.
        dtype: Numpy dtype for the returned audio.

    Returns:
        Converted audio array with shape ``[M]`` for mono or ``[M, target_channels]``.
    """

    data = _to_float32(audio)

    if data.ndim == 1 and source_channels != 1:
        raise ValueError(
            "Mono input data provided but source_channels != 1; update arguments."
        )
    if data.ndim == 2 and data.shape[1] != source_channels:
        raise ValueError("Mismatch between input array channels and source_channels.")

    # Channel conversion.
    if source_channels != target_channels:
        if target_channels == 1:
            data = data.mean(axis=1) if data.ndim == 2 else data
        elif source_channels == 1:
            data = np.repeat(data[:, None], target_channels, axis=1)
        else:
            # Down-mix to mono then duplicate to target channels.
            mono = data.mean(axis=1)
            data = np.repeat(mono[:, None], target_channels, axis=1)

    # Sample-rate conversion.
    if source_rate != target_rate:
        if data.ndim == 1:
            data = _resample(data, source_rate, target_rate)
        else:
            channels = [
                _resample(data[:, ch], source_rate, target_rate)
                for ch in range(data.shape[1])
            ]
            data = np.stack(channels, axis=1)

    return data.astype(dtype, copy=False)


def _resample(audio: NDArray[np.float32], src_rate: int, dst_rate: int) -> NDArray[np.float32]:
    """Resample a 1-D signal using polyphase filtering."""
    if src_rate <= 0 or dst_rate <= 0:
        raise ValueError("Sample rates must be positive integers.")

    if src_rate == dst_rate:
        return audio

    factor = gcd(src_rate, dst_rate)
    up = dst_rate // factor
    down = src_rate // factor
    return signal.resample_poly(audio, up=up, down=down)


def normalize_volume(audio: ArrayLike, target_level_dbfs: float = -20.0) -> NDArray[np.float32]:
    """Normalise audio loudness to the requested full-scale decibel level.

    The function rescales the signal to reach the desired RMS loudness while
    keeping the waveform in floating-point representation (typically ``[-1, 1]``).

    Args:
        audio: Input audio samples.
        target_level_dbfs: Target loudness relative to digital full scale in dBFS.

    Returns:
        Loudness-normalised audio samples as ``float32``.
    """

    data = _to_float32(audio)
    rms = np.sqrt(np.mean(np.square(data)) + _EPS)
    current_level = 20.0 * np.log10(rms + _EPS)
    gain_db = target_level_dbfs - current_level
    gain = 10 ** (gain_db / 20.0)
    return np.clip(data * gain, -1.0, 1.0)


def reduce_noise(
    audio: ArrayLike,
    sample_rate: int,
    noise_reduction: float = 0.8,
    n_fft: int = 1024,
    hop_length: Optional[int] = None,
    beta: float = 1.5,
) -> NDArray[np.float32]:
    """Apply a lightweight spectral-gating noise suppression.

    Args:
        audio: Input audio samples (mono or multi-channel). Multi-channel input
            is processed independently per channel.
        sample_rate: Sampling rate in Hz.
        noise_reduction: Proportion of the estimated noise magnitude to remove.
            Values in ``[0, 1]`` are recommended.
        n_fft: FFT window size.
        hop_length: Hop size between frames. Defaults to ``n_fft // 4``.
        beta: Exponent controlling aggressiveness of the noise mask.

    Returns:
        Audio with broadband stationary noise attenuated.
    """

    if not 0.0 <= noise_reduction <= 1.0:
        raise ValueError("noise_reduction must be within [0, 1].")

    data = _to_float32(audio)
    hop = hop_length or n_fft // 4

    if data.ndim == 1:
        return _reduce_noise_single(data, sample_rate, noise_reduction, n_fft, hop, beta)

    denoised = [
        _reduce_noise_single(data[:, ch], sample_rate, noise_reduction, n_fft, hop, beta)
        for ch in range(data.shape[1])
    ]
    return np.stack(denoised, axis=1)


def _reduce_noise_single(
    audio: NDArray[np.float32],
    sample_rate: int,
    noise_reduction: float,
    n_fft: int,
    hop_length: int,
    beta: float,
) -> NDArray[np.float32]:
    _, _, stft_matrix = signal.stft(
        audio, fs=sample_rate, nperseg=n_fft, noverlap=n_fft - hop_length
    )
    magnitude = np.abs(stft_matrix)
    noise_profile = np.percentile(magnitude, 20, axis=1, keepdims=True)
    noise_profile = np.maximum(noise_profile, _EPS)

    # Construct a soft mask favouring spectral components above the noise floor.
    mask = 1.0 - noise_reduction * (noise_profile / (magnitude + _EPS)) ** beta
    mask = np.clip(mask, 0.0, 1.0)
    cleaned = stft_matrix * mask

    _, recovered = signal.istft(
        cleaned,
        fs=sample_rate,
        nperseg=n_fft,
        noverlap=n_fft - hop_length,
        input_onesided=True,
    )
    recovered = np.asarray(recovered, dtype=np.float32)
    if recovered.shape[0] < audio.shape[0]:
        recovered = np.pad(recovered, (0, audio.shape[0] - recovered.shape[0]))
    return recovered[: audio.shape[0]]


def compute_spectrogram(
    audio: ArrayLike,
    sample_rate: int,
    n_fft: int = 1024,
    hop_length: Optional[int] = None,
    window: str = "hann",
    power: float = 2.0,
) -> Tuple[NDArray[np.float32], NDArray[np.float32], NDArray[np.float32]]:
    """Compute a magnitude or power spectrogram for diagnostics or visualisation.

    Args:
        audio: Audio samples (mono).
        sample_rate: Sampling rate in Hz.
        n_fft: FFT window size.
        hop_length: Hop size in samples. Defaults to ``n_fft // 4``.
        window: FFT window type passed to ``scipy.signal.get_window``.
        power: If 1.0 returns magnitude, if 2.0 returns power spectrogram.

    Returns:
        Tuple of ``(frequencies, times, spectrogram)`` where the spectrogram is a
        ``float32`` matrix with shape ``[freq_bins, frames]``.
    """

    data = _to_float32(audio)
    if data.ndim != 1:
        raise ValueError("Spectrogram computation expects mono audio input.")

    hop = hop_length or n_fft // 4
    window_fn = signal.get_window(window, n_fft)
    freqs, times, stft_matrix = signal.stft(
        data, fs=sample_rate, window=window_fn, nperseg=n_fft, noverlap=n_fft - hop
    )
    magnitude = np.abs(stft_matrix)
    if power == 1.0:
        spec = magnitude
    elif power == 2.0:
        spec = magnitude ** 2
    else:
        spec = magnitude ** power
    return freqs.astype(np.float32), times.astype(np.float32), spec.astype(np.float32)


@dataclass(frozen=True)
class QualityReport:
    """Structured result returned by :func:`evaluate_quality`."""

    duration: float
    rms_level_dbfs: float
    snr_db: float
    zero_crossing_rate: float
    spectral_centroid_hz: float
    clipping_ratio: float


def evaluate_quality(audio: ArrayLike, sample_rate: int, frame_duration: float = 0.02) -> QualityReport:
    """Assess fundamental signal-quality indicators for recorded audio.

    The routine does not replace perceptual metrics such as PESQ, but it offers
    lightweight heuristics that highlight common capture issues (e.g., excessive
    noise, clipping, or overly quiet recordings).

    Args:
        audio: Input audio samples (mono).
        sample_rate: Sample rate of ``audio``.
        frame_duration: Analysis frame duration in seconds used to estimate SNR.

    Returns:
        :class:`QualityReport` containing the computed metrics.
    """

    data = _to_float32(audio)
    if data.ndim != 1:
        raise ValueError("Quality evaluation expects mono audio input.")

    if data.size == 0:
        return QualityReport(
            duration=0.0,
            rms_level_dbfs=float("-inf"),
            snr_db=0.0,
            zero_crossing_rate=0.0,
            spectral_centroid_hz=0.0,
            clipping_ratio=0.0,
        )

    duration = len(data) / float(sample_rate)
    rms = np.sqrt(np.mean(np.square(data)) + _EPS)
    rms_dbfs = 20.0 * np.log10(rms + _EPS)

    frame_length = max(1, int(frame_duration * sample_rate))
    if frame_length > len(data):
        frame_length = len(data)
    hop_length = max(1, frame_length // 2)

    frames = _frame_signal(data, frame_length, hop_length)
    frame_energy = np.mean(np.square(frames), axis=1) + _EPS
    noise_power = np.percentile(frame_energy, 10)
    signal_power = np.percentile(frame_energy, 90)
    snr_db = 10.0 * np.log10(signal_power / noise_power)

    zero_crossings = np.nonzero(np.diff(np.signbit(data)))[0]
    zero_crossing_rate = len(zero_crossings) / duration if duration > 0 else 0.0

    freqs, _, spec = compute_spectrogram(data, sample_rate, n_fft=1024, hop_length=512)
    spec_power = spec if spec.ndim == 2 else spec[np.newaxis, :]
    spectral_centroid = np.sum(freqs[:, None] * spec_power, axis=0) / (
        np.sum(spec_power, axis=0) + _EPS
    )
    spectral_centroid_hz = float(np.mean(spectral_centroid))

    clipping_ratio = float(np.mean(np.abs(data) > 0.99))

    return QualityReport(
        duration=duration,
        rms_level_dbfs=rms_dbfs,
        snr_db=snr_db,
        zero_crossing_rate=zero_crossing_rate,
        spectral_centroid_hz=spectral_centroid_hz,
        clipping_ratio=clipping_ratio,
    )


def _frame_signal(
    audio: NDArray[np.float32], frame_length: int, hop_length: int
) -> NDArray[np.float32]:
    """Slice a 1-D signal into overlapping frames."""
    if frame_length <= 0 or hop_length <= 0:
        raise ValueError("frame_length and hop_length must be positive integers.")
    num_frames = 1 + max(0, (len(audio) - frame_length) // hop_length)
    if num_frames <= 1:
        return audio[:frame_length][None, :]

    strides = (audio.strides[0] * hop_length, audio.strides[0])
    shape = (num_frames, frame_length)
    frames = np.lib.stride_tricks.as_strided(audio, shape=shape, strides=strides)
    return np.array(frames, copy=True)


__all__ = [
    "QualityReport",
    "compute_spectrogram",
    "convert_format",
    "evaluate_quality",
    "normalize_volume",
    "reduce_noise",
]
