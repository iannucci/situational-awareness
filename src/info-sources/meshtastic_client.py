# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

import meshtastic.tcp_interface as meshtastic_tcp

from pubsub import pub  # https://pypubsub.readthedocs.io/en/v4.0.3/
import logging
import config as CF
import argparse
import time
from mattermost_client import MattermostClient
import pprint
import scenario_db as DB


def build_logger(level: str):
    logging.basicConfig(level=level, format="%(asctime)s %(levelname)s %(message)s")
    return logging.getLogger("meshtastic_client")


def loggerInfo(my_logger):
    for name, logger in logging.Logger.manager.loggerDict.items():
        if isinstance(logger, logging.Logger):
            my_logger.info(
                f"🚨 [Meshtastic] Logger Name: {name}, Level: {logging.getLevelName(logger.getEffectiveLevel())}"
            )


class MeshtasticClient:
    def __init__(self, config, mattermost_callback, database):
        self.config = config
        self.meshtastic_config = config.get("meshtastic", None)
        self.database_config = config.get("database", None)
        self.meshtastic_host = self.meshtastic_config.get("host", "")
        self.mattermost_callback = mattermost_callback
        self.logger = build_logger(self.meshtastic_config.get("log_level", "INFO"))
        self.meshtastic_interface = None
        self.database = database
        self.esv_dict = {}
        self.tracked_asset_type_set = set()
        # Establish a connection to the Meshtastic device
        try:
            self.meshtastic_interface = meshtastic_tcp.TCPInterface(
                hostname=self.meshtastic_host,
                portNumber=4403,
                connectNow=True,
                debugOut=None,
            )
            logging.getLogger("meshtastic.tcp_interface").setLevel(logging.INFO)
            logging.getLogger("meshtastic-client").setLevel(logging.INFO)
            logging.getLogger("meshtastic").setLevel(logging.INFO)
            logging.getLogger("meshtastic_client").setLevel(logging.INFO)
            pub.setNotificationFlags(all=False)
            pub.subscribe(self._onReceive, "meshtastic.receive")
            pub.subscribe(self._onPositionReceive, "meshtastic.receive.position")
            pub.subscribe(self._onTelemetryReceive, "meshtastic.receive.telemetry")
            self.logger.info(
                "✅ [Meshtastic] Connected to Meshtastic device and listening for messages"
            )
        except Exception as e:
            self.logger.error(f"❌ [Meshtastic] Error connecting to device: {e}")
            raise

    def close(self):
        if self.meshtastic_interface is not None:
            self.meshtastic_interface.close()

    def _update_esv(self, callsign, location):
        if "ESV" not in self.tracked_asset_type_set:
            asset_type = DB.trackedAssetType(
                "ESV", "Emergency Services Volunteer", "OES"
            )
            asset_type.insert(self.database)
            self.tracked_asset_type_set.add("ESV")
        if callsign in self.esv_dict:
            existing_esv = self.esv_dict[callsign]
            existing_esv.location = location
            existing_esv.update()
        else:
            new_esv = DB.esvAsset(callsign, callsign, location)
            new_esv.update(self.database)
            self.esv_dict[callsign] = new_esv

    # Translates a node ID into its short name and long name
    def _id_to_name(self, interface, id):
        short_name = ""
        long_name = ""
        for node_id, node_info in interface.nodes.items():
            if id == node_id:
                user = node_info["user"]
                long_name = user["longName"]
                short_name = user["shortName"]
                break
        return short_name, long_name

    def _onReceive(self, packet, interface):
        # self.logger.info("🚨 [Meshtastic] _onReceive")
        # self.logger.info(f"🚨 [Meshtastic] Received packet <{packet}>")
        # loggerInfo(self.logger)
        if (
            "decoded" in packet
            and "portnum" in packet["decoded"]
            and packet["decoded"]["portnum"] == "TEXT_MESSAGE_APP"
        ):
            try:
                text_message = packet["decoded"]["payload"].decode("utf-8")
                # from_node = packet["from"]
                from_id = packet["fromId"]  # from_id is of the form !da574b90
                _, long_name = self._id_to_name(interface, from_id)
                callsign = long_name.split()[0].upper()
                self.logger.info(
                    f"✅ [Meshtastic] Message from {callsign}: <{text_message}>"
                )
                callback_data = {
                    "type": "message",
                    "callsign": callsign,
                    "message": text_message,
                }
                self.mattermost_callback(callback_data)
            except Exception as e:
                self.logger.error(
                    f"❌ [Meshtastic] Error processing text message packet: {e}"
                )

    def _onPositionReceive(self, packet, interface):
        # self.logger.info("🚨 [Meshtastic] _onPositionReceive")
        # self.logger.info(f"🚨 [Meshtastic] Received packet <{packet}>")
        # loggerInfo(self.logger)
        if (
            "decoded" in packet
            and "portnum" in packet["decoded"]
            and packet["decoded"]["portnum"] == "POSITION_APP"
        ):
            try:
                pos = packet["decoded"]["position"]
                from_id = packet["fromId"]  # from_id is of the form !da574b90
                _, long_name = self._id_to_name(interface, from_id)
                callsign = long_name.split()[0].upper()
                lat = pos.get("latitude", None)
                lon = pos.get("longitude", None)
                alt = pos.get("altitude", None)
                self.logger.info(
                    f"✅ [Meshtastic] Position update from {callsign}: lat={lat}, lon={lon}, alt={alt}"
                )
                callback_data = {
                    "type": "position",
                    "callsign": callsign,
                    "latitude": lat,
                    "longitude": lon,
                    "altitude": alt,
                }
                self.mattermost_callback(callback_data)

                self._update_esv(callsign, {"lat": lat, "lon": lon})

            except Exception as e:
                self.logger.error(
                    f"❌ [Meshtastic] Error processing position packet: {e}"
                )

    def _onTelemetryReceive(self, packet, interface):
        # self.logger.info("🚨 [Meshtastic] _onTelemetryReceive")
        # self.logger.info(f"🚨 [Meshtastic] Received packet <{packet}>")
        # loggerInfo(self.logger)
        if (
            "decoded" in packet
            and "portnum" in packet["decoded"]
            and packet["decoded"]["portnum"] == "TELEMETRY_APP"
        ):
            try:
                telemetry = packet["decoded"]["telemetry"]
                deviceMetrics = telemetry.get("deviceMetrics", None)
                if deviceMetrics is None:
                    return
                from_id = packet.get("fromId", None)  # from_id is of the form !da574b90
                _, long_name = self._id_to_name(interface, from_id)
                callsign = long_name.split()[0].upper()
                battery = deviceMetrics.get("batteryLevel", 0)
                uptime = deviceMetrics.get("uptimeSeconds", 0)
                self.logger.info(
                    f"✅ [Meshtastic] Telemetry update from {callsign}: battery={battery}, uptime={uptime}"
                )
                callback_data = {
                    "type": "telemetry",
                    "callsign": callsign,
                    "battery": battery,
                    "uptime": uptime,
                }
                self.mattermost_callback(callback_data)
            except Exception as e:
                pretty_packet = pprint.pformat(packet, indent=2)
                self.logger.error(
                    f"❌ [Meshtastic] Error processing telemetry packet: {e}\n<{pretty_packet}>"
                )


DEFAULT_CFG = "/etc/situational-awareness/config.json"
DEFAULT_ASSETS = "/etc/situational-awareness/assets.json"


# This file is normally invoked at installation time by a script created in the installer.
#
# When invoked, pass the --config and --assets parameters, typically pointing to
# /etc/{installation-name}/config.json and /etc/{installation-name}/assets.json
def main():
    ap = argparse.ArgumentParser(description="meshtastic-client")
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

    config_repo = CF.Config()  # singleton
    config_repo.load("main", args.config)
    config_repo.load("assets", args.assets)
    config = config_repo.config("main")
    assets_config = config_repo.config("assets")

    logger = build_logger(config["meshtastic"].get("log_level", "INFO"))
    logger.info("✅ [Meshtastic] Logging is active")

    meshtastic_client = None
    mattermost_client = None
    database = None

    try:
        assets_list = assets_config.get("assets", [])
        database = DB.ScenarioDB(config)
        database.load_assets(assets_list)
        mattermost_client = MattermostClient(config)
        meshtastic_client = MeshtasticClient(
            config, mattermost_client.callback, database
        )

        # loggerInfo(logger)

        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("\n🚨 [Meshtastic] Exiting.")
    finally:
        if meshtastic_client is not None:
            meshtastic_client.close()
        if mattermost_client is not None:
            mattermost_client.close()
        if database is not None:
            database.close()


if __name__ == "__main__":
    main()
