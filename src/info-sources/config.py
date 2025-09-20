# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

# Configuration singleton.  Holds config data for any number of keys.

import json
import os
import logging


def build_logger(level: str):
    logging.basicConfig(level=level, format="%(asctime)s %(levelname)s %(message)s")
    return logging.getLogger("config")


# **FIXME**  Search the current directory and /etc/{project}
def generate_config_path(name: str):
    full_path = os.path.abspath(os.path.join(os.getcwd(), f"{name}"))
    if os.path.exists(full_path):
        return full_path
    else:
        return name


def singleton(cls):
    instances = {}

    def get_instance(*args, **kwargs):
        if cls not in instances:
            instances[cls] = cls(*args, **kwargs)
        return instances[cls]

    return get_instance


# e.g., Config("main", "config.json") loads os.path.abspath(path + config.json) to the "main" key
@singleton
class Config:
    def __init__(self):
        self._configs = {}
        self.logger = build_logger(logging.INFO)

    def load(self, key, config_file_name):
        try:
            config_path = generate_config_path(config_file_name)
            self.logger.info(f"🚨 [Config] Path: {config_path}")
            with open(config_path, "r") as f:
                config = json.load(f)
            self._configs[key] = config
            self.logger.info(f"✅ [Config] <{key}> loaded successfully")
        except FileNotFoundError:
            self.logger.info(f"❌ Error: The file '{config_path}' was not found.")
        except json.JSONDecodeError:
            self.logger.info(
                f"❌ Error: Could not decode JSON from '{config_path}'. Check file format."
            )
        except Exception as e:
            self.logger.info(
                f"❌ An unexpected error occurred: {e} while loading configuration"
            )

    def config(self, key):
        if not hasattr(self, "_configs"):
            raise ValueError("❌ Configuration singleton has not been initialized.")
        else:
            return self._configs[key]
