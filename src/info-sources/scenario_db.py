# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

# Scenario database operations

import psycopg2
import config as CF
import argparse


def singleton(cls):
    instances = {}

    def get_instance(*args, **kwargs):
        if cls not in instances:
            instances[cls] = cls(*args, **kwargs)
        return instances[cls]

    return get_instance


@singleton
class ScenarioDB:
    def __init__(self, dbname, user, host, password, args, port=5432):
        self.dbname = dbname
        self.user = user
        self.host = host
        self.password = password
        self.port = port
        self.args = args
        self.conn = None
        self.cursor = None
        self.assets_dict = {}
        self.type_codes_set = set()
        self.type_list = []
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
        self.assets_config = CF("assets", args.assets)
        self._load_assets_from_file()

    def close(self):
        if self.conn:
            self.conn.close()
            print("✅ Database connection closed")

    def _load_assets_from_file(self):
        for asset in self.assets_config.get("assets", []):
            try:
                type_code = asset.get("type", "").upper()
                if type_code not in self.type_codes_set:
                    new_type = trackedAssetType(
                        type_code=type_code,
                        type_name=type_code.replace("_", " ").title(),
                        organization="OES",
                        icon=f"{type_code.lower()}",  # .png, .svg, ...  Needs to be in the web/assets/icons directory
                    )
                    new_type.insert(self.database)
                    self.type_list.append(new_type)
                    self.type_codes_set.add(type_code)
                    print(f"🔖 Found asset type: {type_code}")

                asset_obj = None
                match type_code:
                    case 'BRIDGE':
                        location = asset.get("location", {})
                        lat = location.get("lat")
                        lon = location.get("lon")
                        asset_id = asset.get("asset_id", f"BRIDGE-{lat}-{lon}")
                        if lat is None or lon is None:
                            print(f"❌ Invalid location data for bridge: {location}")
                            continue
                        # asset_id, tactical_call, description, location, url="")
                        asset_obj = bridgeAsset(
                            asset_id,
                            asset_id,
                            description=asset.get("description", ""),
                            location={"lat": lat, "lon": lon},
                            url=asset.get("url", ""),
                        )
                    case _:
                        pass
                # Add it to the database
                if asset_obj.update(self.database): # returns False on failure
                    # Add it to the local asset cache
                    self.assets_dict[asset_id]=asset_obj
                    print(f"✅ Loaded asset: {type_code}")
                else:
                    print("❌ Failed to add asset {asset} to database")
            except Exception as e:
                print("❌ Failed to add asset {asset} to database: {e}")


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

    def update(self, database):
        db_cursor = database.cursor
        if not db_cursor:
            print("❌ No database cursor available for update operation.")
            return
        try:
            rc = db_cursor.execute(
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

            if rc is None:
                # DO NOTHING was triggered
                return False

            db_cursor.execute(
                """
				INSERT INTO tracked_asset_locations (asset_id, activity, location, status, condition_type, condition_severity)
				VALUES (%s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326), %s, %s, %s);
				""",
                (
                    self.asset_id,
                    self.activity,
                    self.location["lon"],
                    self.location["lat"],
                    self.status,
                    self.condition.type,
                    self.condition.severity,
                ),
            )

            database.conn.commit()
            print(f"✅ Updated asset: {self.description}")
        except Exception as e:
            print(f"❌ Error inserting asset {self.description}: {e}")
            return False
        return True


class bridgeAsset(trackedAsset):
    def __init__(self, asset_id, tactical_call, description, location, url=""):
        super().__init__(asset_id, "BRIDGE", tactical_call, description, location, url)


class esvAsset(trackedAsset):
    def __init__(self, asset_id, tactical_call, location):
        super().__init__(asset_id, "ESV", tactical_call, description='', location, url='')


DEFAULT_CFG = "/etc/situational-awareness/config.json"
DEFAULT_ASSETS = "/etc/situational-awareness/assets.json"


# This file is normally not invoked at installation time.  Rather, it is invoked by a script when the
# scenario assets file has been created for a specific drill or event.
#
# When invoked, pass the --config and --assets parameters, typically pointing to
# /etc/{installation-name}/config.json and /etc/{installation-name}/assets.json
def main():
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

    config = CF.Config("main", args.config)

    dbconfig = config.get("database", None)
    if not dbconfig:
        print("❌ Database configuration is missing in the config file.")

    database = ScenarioDB(
        dbconfig.get("dbname"),
        dbconfig.get("user"),
        dbconfig.get("host"),
        dbconfig.get("password"),
        args,
        dbconfig.get("port"),
    )

    database.close()
