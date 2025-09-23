# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

# SMTP client.  Pulls and parses incoming damage assessments

import argparse
import config as CF
import logging
import poplib as POP

DEFAULT_CFG = "config.json"


def build_logger(level: str):
    logging.basicConfig(level=level, format="%(asctime)s %(levelname)s %(message)s")
    return logging.getLogger("pop_client")


class POPClient:
    def __init__(self, config, logger):
        self.config = config
        self.logger = logger
        self.pop_config = config.get("pop", {})
        self.host = self.pop_config.get("host", "pophost")
        self.userid = self.pop_config.get("userid", "unknown")
        self.password = self.pop_config.get("password", "unknown")
        self.connection = None

    # Returns (possibly empty) message list
    def _connect(self):
        message_count = 0
        try:
            if self.connection is None:
                self.connection = POP.POP3(self.host)
            self.connection.user(self.userid)
            self.connection.pass_(self.password)
            self.connection.list()[1]
        except Exception as e:
            self.logger.info(f"❌ [POP] Connection failed: {e}")
        finally:
            return message_count

    def _close(self):
        self.connection.quit()
        self.connection = None

    def messages(self):
        try:
            messages = []
            for i in range(1, self._connect() + 1):
                message = self.connection.retr(i)[1]
                decoded_message = []
                for line in message:
                    decoded_message.append(line.decode("utf-8"))
                messages.append(decoded_message)
                self.connection.dele(i)
        except Exception as e:
            self.logger.info(f"❌ [POP] Could not retrieve messages: {e}")
        finally:
            self._close()
            return messages


# This file is normally invoked at installation time by a script created in the installer.
#
# When invoked, pass the --config parameter, typically pointing to
# /etc/{installation-name}/config.json
def main():
    ap = argparse.ArgumentParser(description="pop-client")
    ap.add_argument(
        "--config",
        default=DEFAULT_CFG,
        help=f"Path to config file (default: {DEFAULT_CFG})",
    )
    args = ap.parse_args()

    config_repo = CF.Config()  # singleton
    config_repo.load("main", args.config)
    config = config_repo.config("main")

    logger = build_logger(config["pop"].get("log_level", "INFO"))
    logger.info("✅ [POP] Logging is active")

    client = POPClient(config, logger)
    print(client.messages())


if __name__ == "__main__":
    main()
