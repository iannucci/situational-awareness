# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

# SMTP client.  Pulls and parses incoming damage assessments

import argparse
import config as CF
import logging
import poplib as POP
import time
from email.parser import BytesParser
from email import message_from_bytes
from email.policy import default

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
            message_list = self.connection.list()[1]
        except Exception as e:
            self.logger.info(f"❌ [POP] Connection failed: {e}")
        finally:
            return len(message_list)

    def _close(self):
        self.connection.quit()
        self.connection = None

    def messages(self):
        try:
            messages = []
            n_messages = self._connect()
            for i in range(1, n_messages + 1):
                lines = self.connection.retr(i)[1]
                message_data = b"\n".join(lines)
                msg = message_from_bytes(message_data, policy=default)
                # self.logger.info("\n--- Message Headers ---")
                headers = {}
                for header, value in msg.items():
                    headers[header] = value
                    # self.logger.info(f"{header}: {value}")

                clean_body = ""
                # self.logger.info("\n--- Message Body ---")
                # Walk through the message parts to find the plain text body
                for part in msg.walk():
                    # Check if the part is plain text
                    if (
                        part.get_content_maintype() == "text"
                        and part.get_content_subtype() == "plain"
                    ):
                        body_bytes = part.get_payload(decode=True)
                        body = body_bytes.decode(errors="ignore")
                        clean_body = (
                            body.replace("\r\n", "\n").replace("\n\n", "\n").strip()
                        )
                        # self.logger.info(clean_body)
                messages.append({"headers": headers, "body": clean_body})
                # self.connection.dele(i)
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
    try:
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

        while True:
            client = POPClient(config, logger)
            messages = client.messages()
            # if messages != []:
            for message in messages:
                logger.info(f"Body: {message['body']}")
            time.sleep(1)

    except KeyboardInterrupt:
        logger.info("\n🚨 [POP] Exiting.")


if __name__ == "__main__":
    main()
