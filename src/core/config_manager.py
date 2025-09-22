"""Configuration management utilities for the speech AI project."""
from __future__ import annotations

from copy import deepcopy
from collections.abc import Mapping, MutableMapping
from dataclasses import MISSING, dataclass, field, fields
from pathlib import Path
from threading import Lock
from typing import Any, Dict, Optional, Type, TypeVar

import os

import yaml


T = TypeVar("T")


class _SingletonMeta(type):
    """Thread-safe singleton metaclass for the configuration manager."""

    _instances: Dict[type, "ConfigManager"] = {}
    _lock: Lock = Lock()

    def __call__(cls, *args: Any, **kwargs: Any) -> "ConfigManager":  # type: ignore[override]
        with cls._lock:
            if cls not in cls._instances:
                instance = super().__call__(*args, **kwargs)
                cls._instances[cls] = instance
        return cls._instances[cls]


@dataclass
class BaseSectionConfig:
    """Base configuration section supporting storage for unspecified options."""

    extras: Dict[str, Any] = field(default_factory=dict, init=False)


@dataclass
class AudioConfig(BaseSectionConfig):
    """Audio processing configuration values."""

    sample_rate: int = 16_000
    channels: int = 1
    frame_length: float = 0.025
    frame_shift: float = 0.01
    format: Optional[str] = None


@dataclass
class ASRConfig(BaseSectionConfig):
    """Automatic speech recognition configuration values."""

    model_path: Optional[str] = None
    language: str = "en"
    beam_width: int = 10
    max_alternatives: int = 1


@dataclass
class NLUConfig(BaseSectionConfig):
    """Natural language understanding configuration values."""

    intent_model: Optional[str] = None
    entity_model: Optional[str] = None
    confidence_threshold: float = 0.5


@dataclass
class DialogueConfig(BaseSectionConfig):
    """Dialogue management configuration values."""

    policy: str = "rule_based"
    max_turns: int = 10
    fallback_action: Optional[str] = None


@dataclass
class EvaluationConfig(BaseSectionConfig):
    """Evaluation configuration values."""

    dataset_path: Optional[str] = None
    metrics: list[str] = field(default_factory=list)
    save_reports: bool = False


@dataclass
class TTSConfig(BaseSectionConfig):
    """Text-to-speech configuration values."""

    voice: Optional[str] = None
    speed: float = 1.0
    sample_rate: int = 22_050


class ConfigManager(metaclass=_SingletonMeta):
    """Singleton configuration manager supporting YAML files and environment overrides."""

    def __init__(
        self,
        config_path: Optional[Path | str] = None,
        *,
        env_override: bool = True,
    ) -> None:
        self._config_path: Optional[Path] = None
        self._raw_config: Dict[str, Any] = {}
        self._audio_config: Optional[AudioConfig] = None
        self._asr_config: Optional[ASRConfig] = None
        self._nlu_config: Optional[NLUConfig] = None
        self._dialogue_config: Optional[DialogueConfig] = None
        self._evaluation_config: Optional[EvaluationConfig] = None
        self._tts_config: Optional[TTSConfig] = None
        self._env_override = env_override

        if config_path is not None:
            self.load_config(config_path, env_override=env_override)

    @property
    def config_path(self) -> Optional[Path]:
        """Return the path to the loaded configuration file, if any."""

        return self._config_path

    @property
    def is_loaded(self) -> bool:
        """Indicate whether a configuration file has been loaded."""

        return bool(self._raw_config)

    def load_config(self, config_path: Path | str, *, env_override: Optional[bool] = None) -> None:
        """Load configuration from a YAML file and apply environment overrides."""

        path = Path(config_path)
        if not path.exists():
            raise FileNotFoundError(f"Configuration file not found: {path}")

        with path.open("r", encoding="utf-8") as fp:
            data = yaml.safe_load(fp) or {}

        if not isinstance(data, Mapping):
            raise ValueError("Configuration file must contain a mapping at the top level.")

        data_dict = dict(data)

        if env_override is None:
            env_override = self._env_override

        if env_override:
            data_dict = self._apply_env_overrides(data_dict)

        self._raw_config = data_dict
        self._config_path = path
        self._build_typed_configs()

    def reload(self) -> None:
        """Reload the configuration file from the stored path."""

        if self._config_path is None:
            raise RuntimeError("No configuration file has been loaded yet.")

        self.load_config(self._config_path, env_override=self._env_override)

    def get_audio_config(self) -> AudioConfig:
        self._ensure_loaded()
        assert self._audio_config is not None
        return self._audio_config

    def get_asr_config(self) -> ASRConfig:
        self._ensure_loaded()
        assert self._asr_config is not None
        return self._asr_config

    def get_nlu_config(self) -> NLUConfig:
        self._ensure_loaded()
        assert self._nlu_config is not None
        return self._nlu_config

    def get_dialogue_config(self) -> DialogueConfig:
        self._ensure_loaded()
        assert self._dialogue_config is not None
        return self._dialogue_config

    def get_evaluation_config(self) -> EvaluationConfig:
        self._ensure_loaded()
        assert self._evaluation_config is not None
        return self._evaluation_config

    def get_tts_config(self) -> TTSConfig:
        self._ensure_loaded()
        assert self._tts_config is not None
        return self._tts_config

    def get_section(self, section: str, model: Type[T]) -> T:
        """Retrieve a configuration section using the provided dataclass type."""

        self._ensure_loaded()
        section_data = self._raw_config.get(section)
        if section_data is None:
            raise KeyError(f"Configuration section '{section}' not found.")
        if not isinstance(section_data, Mapping):
            raise ValueError(f"Configuration section '{section}' must be a mapping.")
        return self._map_to_dataclass(model, section_data)

    def to_dict(self) -> Dict[str, Any]:
        """Return the raw configuration mapping."""

        self._ensure_loaded()
        return dict(self._raw_config)

    def _ensure_loaded(self) -> None:
        if not self._raw_config:
            raise RuntimeError("Configuration has not been loaded yet. Call load_config() first.")

    def _build_typed_configs(self) -> None:
        """Convert raw configuration into typed dataclass instances."""

        self._audio_config = self._map_to_dataclass(AudioConfig, self._raw_config.get("audio", {}))
        self._asr_config = self._map_to_dataclass(ASRConfig, self._raw_config.get("asr", {}))
        self._nlu_config = self._map_to_dataclass(NLUConfig, self._raw_config.get("nlu", {}))
        self._dialogue_config = self._map_to_dataclass(DialogueConfig, self._raw_config.get("dialogue", {}))
        self._evaluation_config = self._map_to_dataclass(EvaluationConfig, self._raw_config.get("evaluation", {}))
        self._tts_config = self._map_to_dataclass(TTSConfig, self._raw_config.get("tts", {}))

    def _map_to_dataclass(self, model: Type[T], data: Mapping[str, Any]) -> T:
        if not isinstance(data, Mapping):
            raise ValueError(f"Expected mapping for configuration, received {type(data)!r}.")

        model_fields = {f.name: f for f in fields(model)}
        init_kwargs: Dict[str, Any] = {}

        for name, field_info in model_fields.items():
            if not field_info.init:
                continue
            if name in data:
                init_kwargs[name] = data[name]
            elif field_info.default is not MISSING:
                continue
            elif getattr(field_info, "default_factory", MISSING) is not MISSING:
                continue
            else:
                raise KeyError(f"Missing required configuration value '{name}' for {model.__name__}.")

        instance = model(**init_kwargs)  # type: ignore[arg-type]
        extras_keys = set(data.keys()) - set(model_fields.keys())
        extras = {key: data[key] for key in extras_keys}
        if extras:
            if hasattr(instance, "extras") and isinstance(getattr(instance, "extras"), dict):
                getattr(instance, "extras").update(extras)
            else:
                raise ValueError(
                    f"Unexpected configuration options for {model.__name__}: {', '.join(sorted(extras))}"
                )

        return instance

    def _apply_env_overrides(self, config: MutableMapping[str, Any]) -> Dict[str, Any]:
        """Apply environment variable overrides using double underscore separated keys."""

        merged = deepcopy(config)

        for env_key, env_value in os.environ.items():
            path = env_key.lower().split("__")
            if len(path) < 2:
                continue

            section = path[0]
            if section not in merged:
                continue

            target: MutableMapping[str, Any] | None = merged.get(section)
            if not isinstance(target, MutableMapping):
                continue

            for part in path[1:-1]:
                if part not in target or not isinstance(target[part], MutableMapping):
                    target[part] = {}
                target = target[part]  # type: ignore[assignment]

            if isinstance(target, MutableMapping):
                target[path[-1]] = yaml.safe_load(env_value)

        return merged
