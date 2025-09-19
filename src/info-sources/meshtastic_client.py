# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

import meshtastic.tcp_interface as meshtastic_tcp

from pubsub import pub  # https://pypubsub.readthedocs.io/en/v4.0.3/
import logging
import os
import argparse
import json
import time
from mattermost_client import MattermostClient
import pprint

DEFAULT_CFG = "/etc/situational-awareness/config.json"


def loggerInfo(my_logger):
    for name, logger in logging.Logger.manager.loggerDict.items():
        if isinstance(logger, logging.Logger):
            my_logger.info(
                f"🚨 [Meshtastic] Logger Name: {name}, Level: {logging.getLevelName(logger.getEffectiveLevel())}"
            )


class MeshtasticClient:
    def __init__(self, host, callback, logger):
        self.host = host
        self.callback = callback
        self.logger = logger
        self.interface = None
        # Establish a connection to the Meshtastic device
        try:
            self.interface = meshtastic_tcp.TCPInterface(
                hostname=self.host, portNumber=4403, connectNow=True, debugOut=None
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
        self.interface.close()

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
                self.callback(callback_data)
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
                self.callback(callback_data)
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
                telemetry = packet["decoded"]["telemetry"]["deviceMetrics"]
                from_id = packet["fromId"]  # from_id is of the form !da574b90
                _, long_name = self._id_to_name(interface, from_id)
                callsign = long_name.split()[0].upper()
                battery = telemetry.get("battery_level", None)
                uptime = telemetry.get("uptime_seconds", None)
                self.logger.info(
                    f"✅ [Meshtastic] Telemetry update from {callsign}: battery={battery}, uptime={uptime}"
                )
                callback_data = {
                    "type": "position",
                    "callsign": callsign,
                    "battery": battery,
                    "uptime": uptime,
                }
                self.callback(callback_data)
            except Exception as e:
                pretty_packet = pprint.pformat(packet, indent=2)
                self.logger.error(
                    f"❌ [Meshtastic] Error processing telemetry packet: {e}\n<{pretty_packet}>"
                )


def find_config_path(cli_path: str):
    cwd_cfg = os.path.abspath(os.path.join(os.getcwd(), "config.json"))
    if os.path.exists(cwd_cfg):
        return cwd_cfg
    return cli_path


def build_logger(level: str):
    logging.basicConfig(level=level, format="%(asctime)s %(levelname)s %(message)s")
    return logging.getLogger("meshtastic_client")


def main():
    ap = argparse.ArgumentParser(description="meshtastic-client")
    ap.add_argument(
        "--config",
        default=DEFAULT_CFG,
        help=f"Path to config file (default: {DEFAULT_CFG})",
    )
    args = ap.parse_args()
    config_path = find_config_path(args.config)
    try:
        with open(config_path, "r", encoding="utf-8") as config_file:
            config = json.load(config_file)
    except Exception as e:
        print(f"❌ [Meshtastic] Error loading config {config_path}: {e}")
        return
    logger = build_logger(config.get("log_level", "INFO"))
    logger.info("✅ [Meshtastic] Logging is active")

    meshtastic_client = None
    mattermost_client = None

    try:
        meshtastic_config = config.get("meshtastic", {})
        mattermost_config = config.get("mattermost", {})
        mattermost_client = MattermostClient(mattermost_config, logger)
        meshtastic_client = MeshtasticClient(
            meshtastic_config.get("host", ""), mattermost_client.callback, logger
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


if __name__ == "__main__":
    main()
