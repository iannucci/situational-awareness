# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

# Configuration singleton.  Holds config data for any number of keys.

import json
import os


# **FIXME**  Search the current directory and /etc/{project}
def config_path(name: str):
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
    def __init__(self, key, config_file_name):
        if not hasattr(self, "classes"):
            self._configs = {}
        try:
            config_path = config_path(config_file_name)
            with open(config_path, "r") as f:
                config = json.load(f)
            self._configs[key] = config
            print("✅ Configuration <{key}> loaded successfully")
        except FileNotFoundError:
            print(f"❌ Error: The file '{config_path}' was not found.")
        except json.JSONDecodeError:
            print(
                f"❌ Error: Could not decode JSON from '{config_path}'. Check file format."
            )
        except Exception as e:
            print(f"❌ An unexpected error occurred: {e} while loading configuration")
        return config

    def configs(self):
        if not hasattr(self, "classes"):
            raise ValueError("❌ Configuration singleton has not been initialized.")
        else:
            return self._configs
