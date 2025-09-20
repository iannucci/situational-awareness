# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

from mattermostdriver import Driver


class MattermostClient:
    def __init__(self, config, logger):
        self.host = config.get("host", "")
        self.scheme = config.get("scheme", "http")
        self.port = int(config.get("port", 80))
        self.basepath = config.get("basepath", "/api/v4").rstrip("/")
        self.team = config.get("team", "")
        self.admin_token = config.get("admin-token", "")
        self.users = config.get("users", [])
        self.mattermost_login_config = {
            "url": self.host,
            "token": self.admin_token,
            "scheme": self.scheme,
            "port": self.port,
            "basepath": self.basepath,
        }
        self.logger = logger
        self.admin_driver = None
        self.user_driver = None

    def close(self):
        if self.user_driver is not None:
            self.user_driver.logout()
            self.user_driver = None
        if self.admin_driver is not None:
            self.admin_driver.logout()
            self.admin_driver = None

    def callback(self, callback_data):
        try:
            self.logger.info(
                f"✅ [Mattermost] Callback <{callback_data["type"]}> received from {callback_data["callsign"]}"
            )
            match callback_data["type"]:
                case "message":
                    pass
                case "position":
                    pass
                case "telemetry":
                    pass
                case _:
                    self.logger.info(
                        f"❌ [Mattermost] Unknown callback type: {callback_data['type']}"
                    )
        except Exception as e:
            self.logger.error(f"❌ [Mattermost] Error in callback: {e}")

    # Returns the text team annd channel names as well as the user's token
    def _lookup_user_by_callsign(self, callsign):
        team = ""
        channel = ""
        token = ""
        callsign_lower = callsign.lower()
        for user in self.users:
            if user["callsign"] == callsign_lower:
                team = user["team"]
                channel = user["channel"]
                token = user["token"]
                break
        return team, channel, token

    def _get_channel_id_by_name(self, channel_name, team_name, user_name):
        try:
            self.admin_driver = Driver(self.mattermost_login_config)
            self.admin_driver.login()
        except Exception as e:
            self.logger.error(
                f"[Mattermost] Could not establish a connection to the Mattermost server {self.host} for the admin user"
            )
        user_id = self.admin_driver.users.get_user_by_username(user_name).get("id")
        teams = self.admin_driver.teams.get_user_teams(user_id)
        team = next((team for team in teams if team["display_name"] == team_name), None)
        if team is None:
            self.logger.warning(
                f"[Mattermost] Team {team_name} not found for user {user_name}."
            )
            return
        team_id = team["id"]
        channels = self.admin_driver.channels.get_channels_for_user(user_id, team_id)
        if not channels:
            self.logger.warning(f"[Mattermost] No channels found for team {team_name}.")
            return
        channel = next(
            (
                channel
                for channel in channels
                if channel["display_name"] == channel_name
            ),
            None,
        )
        if channel is None:
            self.logger.warning(
                f"[Mattermost] Channel {channel_name} not found in team {team_name}."
            )
            return
        self.close()
        return channel["id"]

    def _post(self, callsign, message):
        callsign = (
            callsign.lower()
        )  # the user dictionary and Mattermost use lower case callsigns
        try:
            team, channel, token = self._lookup_user_by_callsign(callsign)
            channel_id = self._get_channel_id_by_name(channel, team, callsign)
            user_login_config = {
                "url": self.host,
                "token": token,
                "scheme": self.scheme,
                "port": self.port,
                "basepath": self.basepath,
            }
            self.user_driver = Driver(user_login_config)
            self.user_driver.login()
            post_dict = {
                "channel_id": channel_id,
                "message": message,
            }
            self.user_driver.posts.create_post(post_dict)
        except Exception as e:
            self.logger.error(
                f"[Mattermost] Could not establish a connection to the Mattermost server {self.host} for user {callsign}"
            )
        finally:
            self.close()
