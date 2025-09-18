# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

# This program is used to set up a scenario.

import json
import psycopg2
import os
import argparse


class ScenarioDB:
    def __init__(self, dbname, user, host, password, port=5432):
        self.dbname = dbname
        self.user = user
        self.host = host
        self.password = password
        self.port = port
        self.conn = None
        self.cursor = None
        try:
            self.conn = psycopg2.connect(
                f"dbname={dbname} user={user} host={host} password={password} port={port}"
            )
            self.cursor = self.conn.cursor()
        except psycopg2.OperationalError as e:
            print(f"❌ Unable to connect to the database: {e}")
            self.conn = None
        else:
            print("✅ Database connection established")

    def close(self):
        if self.conn:
            self.conn.close()
            print("✅ Database connection closed")


class trackedAssetCondition:
    def __init__(self, type="Unknown", severity="Unknown"):
        self.type = type
        self.severity = (
            severity  # one of 'None', 'Unknown', 'Low', 'Medium', 'High', 'Critical'
        )


class trackedAssetType:
    def __init__(self, type_code, type_name, organization, icon="default.png"):
        self.type_code = type_code
        self.type_name = type_name
        self.organization = organization
        self.icon = icon

    def insert(self, database):
        db_cursor = database.cursor
        if not db_cursor:
            print("❌ No database cursor available for insert operation.")
            return
        try:
            db_cursor.execute(
                """
				INSERT INTO tracked_asset_types (type_code, type_name, organization, icon)
				VALUES (%s, %s, %s, %s)
				ON CONFLICT (type_code) DO NOTHING;
				""",
                (
                    self.type_code,
                    self.type_name,
                    self.organization,
                    self.icon,
                ),
            )
            database.conn.commit()
            print(f"✅ Inserted asset type: {self.type_name}")
        except Exception as e:
            print(f"❌ Error inserting asset type {self.type_name}: {e}")


class trackedAsset:
    def __init__(
        self, asset_id, type_code, tactical_call, description, location, url=""
    ):
        self.asset_id = asset_id
        self.type_code = type_code
        self.tactical_call = tactical_call
        self.description = description
        self.location = location
        self.url = url
        self.condition = trackedAssetCondition()
        self.activity = ""
        self.status = "Available"  # one of 'Available', 'Dispatched', 'En Route', "Fixed", 'On Scene', 'Out of Service'

    def insert(self, database):
        db_cursor = database.cursor
        if not db_cursor:
            print("❌ No database cursor available for insert operation.")
            return
        try:
            db_cursor.execute(
                """
				INSERT INTO tracked_assets (asset_id, type_code, tactical_call, description, location, status, url, condition_type, condition_severity)
				VALUES (%s, %s, %s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326), %s, %s, %s, %s)
				ON CONFLICT (asset_id) DO NOTHING;
				""",
                (
                    self.asset_id,
                    self.type_code,
                    self.tactical_call,
                    self.description,
                    self.location["lon"],
                    self.location["lat"],
                    self.status,
                    self.url,
                    self.condition.type,
                    self.condition.severity,
                ),
            )

            db_cursor.execute(
                """
				INSERT INTO tracked_asset_locations (asset_id, activity, location, status, condition_type, condition_severity)
				VALUES (%s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326), %s, %s, %s);
				""",
                (
                    self.asset_id,
                    self.activity,
                    location["lon"],
                    location["lat"],
                    self.status,
                    self.condition.type,
                    self.condition.severity,
                ),
            )

            database.conn.commit()
            print(f"✅ Inserted asset: {self.description}")
        except Exception as e:
            print(f"❌ Error inserting asset {self.description}: {e}")

    def move(self, database, activity, location, status, condition):
        self.activity = activity
        self.location = location
        self.status = status
        self.condition = condition
        print(
            f"🔄 Moving asset: {self.asset_id} to {location} with activity {activity}"
        )
        db_cursor = database.cursor
        if not db_cursor:
            print("❌ No database cursor available for move operation.")
            return
        try:
            db_cursor.execute(
                """
				UPDATE tracked_assets
				SET activity = %s, location = ST_SetSRID(ST_MakePoint(%s, %s), 4326), status = %s, condition_type = %s, condition_severity = %s, updated_at = NOW()
				WHERE asset_id = %s;
				""",
                (
                    activity,
                    location["lon"],
                    location["lat"],
                    status,
                    condition.type,
                    condition.severity,
                    self.asset_id,
                ),
            )
            db_cursor.execute(
                """
				INSERT INTO tracked_asset_locations (asset_id, activity, location, status, condition_type, condition_severity)
				VALUES (%s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326), %s, %s, %s);
				""",
                (
                    self.asset_id,
                    activity,
                    location["lon"],
                    location["lat"],
                    status,
                    condition.type,
                    condition.severity,
                ),
            )

            database.conn.commit()
            print(f"✅ Moved asset: {self.description}")
        except Exception as e:
            print(f"❌ Error moving asset {self.description}: {e}")


class bridgeAsset(trackedAsset):
    def __init__(self, asset_id, tactical_call, description, location, url=""):
        super().__init__(asset_id, "BRIDGE", tactical_call, description, location, url)


DEFAULT_CFG = "/etc/situational-awareness/config.json"
DEFAULT_ASSETS = "/etc/situational-awareness/assets.json"


def find_config_path(cli_path: str):
    cwd_cfg = os.path.abspath(os.path.join(os.getcwd(), "config.json"))
    if os.path.exists(cwd_cfg):
        return cwd_cfg
    return cli_path


ap = argparse.ArgumentParser(description="scenario-setup")
ap.add_argument(
    "--config",
    default=DEFAULT_CFG,
    help=f"Path to config file (default: {DEFAULT_CFG})",
)
ap.add_argument(
    "--assets",
    default=DEFAULT_ASSETS,
    help=f"Path to assets file (default: {DEFAULT_ASSETS})",
)
args = ap.parse_args()

config = {}
try:
    config_path = find_config_path(args.config)
    with open(config_path, "r") as f:
        config = json.load(f)
    print("✅ Configuration data loaded successfully")
except FileNotFoundError:
    print(f"❌ Error: The file '{config_path}' was not found.")
except json.JSONDecodeError:
    print(f"❌ Error: Could not decode JSON from '{config_path}'. Check file format.")
except Exception as e:
    print(f"❌ An unexpected error occurred: {e} while loading configuration")


assets = {}
try:
    assets_path = find_config_path(args.assets)
    with open(assets_path, "r") as f:
        assets = json.load(f)
    print("✅ Fixed asset data loaded successfully")
except FileNotFoundError:
    print(f"❌ Error: The file '{assets_path}' was not found.")
except json.JSONDecodeError:
    print(f"❌ Error: Could not decode JSON from '{assets_path}'. Check file format.")
except Exception as e:
    print(f"❌ An unexpected error occurred: {e} while loading assets")

dbconfig = config.get("database", None)
if not dbconfig:
    print("❌ Database configuration is missing in the config file.")

database = ScenarioDB(
    dbconfig.get("dbname"),
    dbconfig.get("user"),
    dbconfig.get("host"),
    dbconfig.get("password"),
    dbconfig.get("port"),
)

asset_list = []
type_codes_set = set()
type_list = []

for asset in assets.get("assets", []):

    type_code = asset.get("type", "").upper()
    if type_code not in type_codes_set:
        new_type = trackedAssetType(
            type_code=type_code,
            type_name=type_code.replace("_", " ").title(),
            organization="OES",
            icon=f"{type_code.lower()}",  # .png, .svg, ...  Needs to be in the web/assets/icons directory
        )
        new_type.insert(database)
        type_list.append(new_type)
        type_codes_set.add(type_code)
        print(f"🔖 Found asset type: {type_code}")

    if type_code != "BRIDGE":
        continue
    location = asset.get("location", {})
    lat = location.get("lat")
    lon = location.get("lon")
    asset_id = asset.get("asset_id", f"BRIDGE-{lat}-{lon}")
    if lat is None or lon is None:
        print(f"❌ Invalid location data for bridge: {location}")
        continue
    # asset_id, tactical_call, description, location, url="")
    bridge = bridgeAsset(
        asset_id,
        asset_id,
        description=asset.get("description", ""),
        location={"lat": lat, "lon": lon},
        url=asset.get("url", ""),
    )
    asset_list.append(bridge)
    bridge.insert(database)
    print(f"✅ Loaded bridge: {bridge.description} at ({lat}, {lon})")

database.close()
