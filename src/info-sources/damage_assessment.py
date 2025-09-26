# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

import re
import json
from dateutil import parser as date_parser
import argparse
import config as CF
import logging
import psycopg2


def build_logger(level: str):
    logging.basicConfig(level=level, format="%(asctime)s %(levelname)s %(message)s")
    return logging.getLogger("damage_assesssment")


def singleton(cls):
    instances = {}

    def get_instance(*args, **kwargs):
        if cls not in instances:
            instances[cls] = cls(*args, **kwargs)
        return instances[cls]

    return get_instance


@singleton
class DamageDB:

    def __init__(self, config):  # dbname, user, host, password, port=5432):
        self.config = config
        self.damage_config = config.get("damage", {})
        self.dbname = self.damage_config.get("dbname", "damage")
        self.user = self.damage_config.get("user", "default")
        self.host = self.damage_config.get("host", "localhost")
        self.password = self.damage_config.get("password", "default")
        self.port = self.damage_config.get("port", 5432)
        self.logger = build_logger(logging.INFO)
        self.conn = None
        self.cursor = None
        try:
            self.conn = psycopg2.connect(
                f"dbname={self.dbname} user={self.user} host={self.host} password={self.password} port={self.port}"
            )
            self.cursor = self.conn.cursor()
        except psycopg2.OperationalError as e:
            self.logger.info(f"❌ [Damage] Unable to connect to the database: {e}")
            self.conn = None
        else:
            self.logger.info("✅ [Damage] Connection established")

    def close(self):
        if self.conn:
            self.conn.close()
            self.logger.info("✅ [Damage] Connection closed")


# Enter with a dict having these keys with valid values:
example_init_dict = {
    "msg_no": "6EI-007",  # text
    "datetime": "...",  # can be parsed by dateutil.parser
    "handling": "...",  # One of "Immediate", "Priorty", "Routine"
    "to_ics_position": "...",  # text
    "to_location": "...",  # text
    "to_name": "...",  # text
    "to_contact": "...",  # text
    "from_ics_position": "...",  # text
    "from_location": "...",  # text
    "from_name": "...",  # text
    "from_contact": "...",  # text
    "jurisdiction": "...",  # text
    "incident_name": "...",  # text
    "address": "...",  # text
    "unit_suite": "...",  # text or ""
    "type_structure": "...",  # One of "Single Family", "Mobile Home", "Non-Profit Orgs", "Multi-Family", "Business", "Outbuilding"
    "stories": 1,  # Natural number (INT >= 1)
    "own_rent": "...",  # One of "Own", "Rent"
    "type_damage_flooding": False,  # Boolean, optional, default False
    "type_damage_exterior": False,  # Boolean, optional, default False
    "type_damage_structural": False,  # Boolean, optional, default False
    "type_damage_other": False,  # Boolean, optional, default False
    "basement": False,  # Boolean, optional, default False
    "damage_class": "...",  # One of "Destroyed", "Minor", "No Visible Damage", "Major", "Affected"
    "tag": "...",  # One of "Green", "Yellow", "Red"
    "insurance": False,  # Boolean, optional, default False
    "estimate": 0,  # Natural number in US dollars with no $
    "comments": "...",  # Text, default "None"
    "contact_name": "...",  # Text, default "Unknown"
    "contact_phone": "111111111",  # string of ten digits, no leading zero unless unknown, then 0000000000
    "op_relay_rcvd": "...",  # text
    "op_relay_sent": "...",  # text
    "op_name": "...",  # text
    "op_call": "...",  # ^(A[A-L]|K[A-Z]|N[A-Z]|W[A-Z}|K|N|W){1}\d{{1}[A-Z]{1-3}$
    "op_date": "...",  # can be parsed by dateutil.parser
}


class DamageAssessment:
    def __init__(self, init_dict: dict):
        """
        Initialize DamageAssessment with validation of input dictionary.

        Args:
                                        init_dict (dict): Dictionary containing damage assessment report data

        Raises:
                                        KeyError: If mandatory keys are missing
                                        ValueError: If values don't meet validation criteria
                                        TypeError: If values are of wrong type
        """

        # Define mandatory keys (those without default values)
        mandatory_keys = {
            "organization",
            "form_file_name",
            "form_version",
            "msg_no",
            "datetime",
            "handling",
            "to_ics_position",
            "to_location",
            "to_name",
            "to_contact",
            "from_ics_position",
            "from_location",
            "from_name",
            "from_contact",
            "jurisdiction",
            "incident_name",
            "address",
            "unit_suite",
            "type_structure",
            "stories",
            "own_rent",
            "damage_class",
            "tag",
            "estimate",
            "op_relay_rcvd",
            "op_relay_sent",
            "op_name",
            "op_call",
            "op_date",
        }

        # Define optional keys with their default values
        optional_defaults = {
            "type_damage_flooding": False,
            "type_damage_exterior": False,
            "type_damage_structural": False,
            "type_damage_other": False,
            "basement": False,
            "insurance": False,
            "comments": "None",
            "contact_name": "Unknown",
        }

        # Check for missing mandatory keys
        missing_keys = mandatory_keys - set(init_dict.keys())
        if missing_keys:
            raise KeyError(f"Missing mandatory keys: {sorted(missing_keys)}")

        # Validate and set each field
        self._validate_and_set_fields(init_dict, optional_defaults)

    def _validate_and_set_fields(self, init_dict: dict, optional_defaults: dict):
        """Validate and set all instance variables."""

        # Set optional fields with defaults first
        for key, default_value in optional_defaults.items():
            setattr(self, key, init_dict.get(key, default_value))

        # Validate and set mandatory text fields
        text_fields = [
            "organization",
            "form_file_name",
            "form_version",
            "msg_no",
            "to_ics_position",
            "to_location",
            "to_name",
            "to_contact",
            "from_ics_position",
            "from_location",
            "from_name",
            "from_contact",
            "jurisdiction",
            "incident_name",
            "address",
            "unit_suite",
            "op_relay_rcvd",
            "op_relay_sent",
            "op_name",
        ]

        for field in text_fields:
            value = init_dict[field]
            if not isinstance(value, str):
                raise TypeError(f"{field} must be a string, got {type(value)}")
            setattr(self, field, value)

        # Validate comments and contact_name (can be from input or defaults)
        if not isinstance(self.comments, str):
            raise TypeError(f"comments must be a string, got {type(self.comments)}")
        if not isinstance(self.contact_name, str):
            raise TypeError(
                f"contact_name must be a string, got {type(self.contact_name)}"
            )

        # Validate header fields with specific format requirements
        self._validate_header_fields(init_dict)

        # Validate datetime fields
        self._validate_datetime("datetime", init_dict["datetime"])
        self._validate_datetime("op_date", init_dict["op_date"])

        # Validate handling
        valid_handling = {"Immediate", "Priority", "Routine"}
        if init_dict["handling"] not in valid_handling:
            raise ValueError(
                f"handling must be one of {valid_handling}, got '{init_dict['handling']}'"
            )
        self.handling = init_dict["handling"]

        # Validate type_structure
        valid_structures = {
            "Single Family",
            "Mobile Home",
            "Non-Profit Orgs",
            "Multi-Family",
            "Business",
            "Outbuilding",
        }
        if init_dict["type_structure"] not in valid_structures:
            raise ValueError(
                f"type_structure must be one of {valid_structures}, got '{init_dict['type_structure']}'"
            )
        self.type_structure = init_dict["type_structure"]

        # Validate stories
        if not isinstance(init_dict["stories"], int) or init_dict["stories"] < 1:
            raise ValueError(
                f"stories must be a natural number (int >= 1), got {init_dict['stories']}"
            )
        self.stories = init_dict["stories"]

        # Validate own_rent
        valid_own_rent = {"Own", "Rent"}
        if init_dict["own_rent"] not in valid_own_rent:
            raise ValueError(
                f"own_rent must be one of {valid_own_rent}, got '{init_dict['own_rent']}'"
            )
        self.own_rent = init_dict["own_rent"]

        # Validate boolean damage type fields
        boolean_fields = [
            "type_damage_flooding",
            "type_damage_exterior",
            "type_damage_structural",
            "type_damage_other",
            "basement",
            "insurance",
        ]
        for field in boolean_fields:
            if not isinstance(getattr(self, field), bool):
                raise TypeError(
                    f"{field} must be a boolean, got {type(getattr(self, field))}"
                )

        # Validate damage_class
        valid_damage_classes = {
            "Destroyed",
            "Minor",
            "No Visible Damage",
            "Major",
            "Affected",
        }
        if init_dict["damage_class"] not in valid_damage_classes:
            raise ValueError(
                f"damage_class must be one of {valid_damage_classes}, got '{init_dict['damage_class']}'"
            )
        self.damage_class = init_dict["damage_class"]

        # Validate tag
        valid_tags = {"Green", "Yellow", "Red"}
        if init_dict["tag"] not in valid_tags:
            raise ValueError(
                f"tag must be one of {valid_tags}, got '{init_dict['tag']}'"
            )
        self.tag = init_dict["tag"]

        # Validate estimate
        if not isinstance(init_dict["estimate"], int) or init_dict["estimate"] < 0:
            raise ValueError(
                f"estimate must be a non-negative integer, got {init_dict['estimate']}"
            )
        self.estimate = init_dict["estimate"]

        # Validate contact_phone
        self._validate_contact_phone(init_dict.get("contact_phone", "0000000000"))

        # Validate op_call
        self._validate_op_call(init_dict["op_call"])

    def _validate_datetime(self, field_name: str, value: str):
        """Validate that a string can be parsed as a datetime."""
        if not isinstance(value, str):
            raise TypeError(f"{field_name} must be a string, got {type(value)}")
        try:
            parsed_date = date_parser.parse(value)
            setattr(self, field_name, value)
        except (ValueError, TypeError) as e:
            raise ValueError(f"{field_name} could not be parsed as a date: {e}")

    def _validate_contact_phone(self, value: str):
        """Validate contact phone number format."""
        if not isinstance(value, str):
            raise TypeError(f"contact_phone must be a string, got {type(value)}")

        # Check if it's exactly 10 digits or the unknown placeholder
        if value == "0000000000":
            self.contact_phone = value
        elif re.match(r"^[1-9]\d{9}$", value):
            self.contact_phone = value
        else:
            raise ValueError(
                f"contact_phone must be 10 digits with no leading zero (or '0000000000' if unknown), got '{value}'"
            )

    def _validate_op_call(self, value: str):
        """Validate operator call sign format."""
        if not isinstance(value, str):
            raise TypeError(f"op_call must be a string, got {type(value)}")

        # Regex pattern from the comments (with corrected syntax)
        pattern = r"^(A[A-L]|K[A-Z]|N[A-Z]|W[A-Z]|K|N|W){1}\d{1}[A-Z]{1,3}$"

        if not re.match(pattern, value):
            raise ValueError(
                f"op_call must match amateur radio call sign pattern, got '{value}'"
            )

        self.op_call = value

    def _validate_header_fields(self, init_dict: dict):
        """Validate header fields with specific format requirements."""

        # Validate organization (should be exactly !SCCoPIFO!)
        if init_dict["organization"] != "!SCCoPIFO!":
            raise ValueError(
                f"organization must be '!SCCoPIFO!', got '{init_dict['organization']}'"
            )

        # Validate form_file_name (should have a web file extension)
        form_file = init_dict["form_file_name"]
        valid_extensions = [".htm", ".html", ".asp", ".aspx", ".php", ".jsp"]
        if not any(form_file.lower().endswith(ext) for ext in valid_extensions):
            raise ValueError(
                f"form_file_name must have a web file extension, got '{form_file}'"
            )

        # Validate form_version (should start with integer.something)
        version = init_dict["form_version"]
        if not re.match(r"^\d+\..+", version):
            raise ValueError(
                f"form_version must start with integer followed by period, got '{version}'"
            )

    def to_dict(self) -> dict:
        """
        Return a dictionary containing all instance variables.

        Returns:
                                        dict: Dictionary with all instance variable names as keys and their values
        """
        return self.__dict__.copy()

    def to_json(self) -> str:
        """
        Return a JSON string representation of all instance variables.

        Returns:
                                        str: JSON string containing all instance variables
        """
        return json.dumps(self.__dict__, indent=2)

    def to_message_format(self) -> str:
        """
        Return the instance data in the original text message format.

        Returns:
                                        str: Formatted text message with sorted field lines
        """
        lines = []

        # Add header lines (first 3 lines)
        lines.append(self.organization)
        lines.append(f"#T: {self.form_file_name}")
        lines.append(f"#V: {self.form_version}")

        # Add MsgNo as 4th line
        lines.append(f"MsgNo: [{self.msg_no}]")

        # Create reverse mapping from instance variable to name prefix (excluding MsgNo)
        field_to_prefix = {
            "handling": "5",
            "to_ics_position": "7a",
            "to_location": "7b",
            "to_name": "7c",
            "to_contact": "7d",
            "from_ics_position": "8a",
            "from_location": "8b",
            "from_name": "8c",
            "from_contact": "8d",
            "jurisdiction": "20",
            "incident_name": "21",
            "address": "22",
            "unit_suite": "23",
            "type_structure": "24",
            "stories": "25",
            "own_rent": "26",
            "type_damage_flooding": "27a",
            "type_damage_exterior": "27b",
            "type_damage_structural": "27c",
            "type_damage_other": "27d",
            "basement": "28",
            "damage_class": "29",
            "tag": "30",
            "insurance": "31",
            "estimate": "32",
            "comments": "33",
            "contact_name": "34",
            "contact_phone": "35",
            "op_relay_rcvd": "OpRelayRcvd",
            "op_relay_sent": "OpRelaySent",
            "op_name": "OpName",
            "op_call": "OpCall",
        }

        # Collect field lines for sorting
        field_lines = []

        # Handle datetime split into date (1a) and time (1b)
        if hasattr(self, "datetime"):
            try:
                from dateutil import parser as date_parser

                dt = date_parser.parse(self.datetime)
                date_str = dt.strftime("%m/%d/%Y")
                time_str = dt.strftime("%H:%M")
                field_lines.append(("1a", f"1a.: [{date_str}]"))
                field_lines.append(("1b", f"1b.: [{time_str}]"))
            except:
                # Fallback if parsing fails
                field_lines.append(
                    (
                        "1a",
                        f"1a.: [{self.datetime.split()[0] if ' ' in self.datetime else self.datetime}]",
                    )
                )
                field_lines.append(("1b", f"1b.: [00:00]"))

        # Handle op_date split into OpDate and OpTime
        if hasattr(self, "op_date"):
            try:
                from dateutil import parser as date_parser

                dt = date_parser.parse(self.op_date)
                date_str = dt.strftime("%m/%d/%Y")
                time_str = dt.strftime("%H:%M")
                field_lines.append(("OpDate", f"OpDate: [{date_str}]"))
                field_lines.append(("OpTime", f"OpTime: [{time_str}]"))
            except:
                # Fallback if parsing fails
                field_lines.append(
                    (
                        "OpDate",
                        f"OpDate: [{self.op_date.split()[0] if ' ' in self.op_date else self.op_date}]",
                    )
                )
                field_lines.append(("OpTime", f"OpTime: [00:00]"))

        # Process regular fields
        for field_name, prefix in field_to_prefix.items():
            if hasattr(self, field_name):
                value = getattr(self, field_name)
                formatted_value = self._format_field_value(field_name, value)

                # Add period after numeric prefixes
                if prefix.isdigit() or (len(prefix) > 1 and prefix[:-1].isdigit()):
                    formatted_prefix = f"{prefix}.:"
                else:
                    formatted_prefix = f"{prefix}:"

                field_lines.append((prefix, f"{formatted_prefix} [{formatted_value}]"))

        # Sort field lines by prefix (handling mixed numeric/alpha sorting)
        def sort_key(item):
            prefix = item[0]
            # Extract numeric part for proper sorting
            if prefix.isdigit():
                return (0, int(prefix), "")
            elif len(prefix) > 1 and prefix[:-1].isdigit():
                return (0, int(prefix[:-1]), prefix[-1])
            else:
                return (1, 0, prefix)

        field_lines.sort(key=sort_key)

        # Add sorted field lines to output
        for _, line in field_lines:
            lines.append(line)

        # Add closing line
        lines.append("!/ADDON!")

        return "\n".join(lines)

    def _format_field_value(self, field_name: str, value) -> str:
        """Format a field value for text message output."""

        # Handle insurance field with Yes/No format
        if field_name == "insurance":
            return "Yes" if value else "No"

        # Handle other boolean fields with checked format
        boolean_fields = {
            "type_damage_flooding",
            "type_damage_exterior",
            "type_damage_structural",
            "type_damage_other",
            "basement",
        }
        if field_name in boolean_fields:
            return "checked" if value else ""

        # Handle unit_suite empty string
        if field_name == "unit_suite" and value == "":
            return "None"

        # Convert everything else to string
        return str(value)

    def save_to_database(self, connection):
        """
        Save the DamageAssessment instance to PostgreSQL database.

        Args:
                                        connection: psycopg2 database connection object

        Returns:
                                        int: The ID of the inserted record

        Raises:
                                        Exception: If database operation fails
        """
        import psycopg2
        from dateutil import parser as date_parser

        try:
            with connection.cursor() as cursor:
                # Parse datetime strings to timestamp objects
                dt_parsed = date_parser.parse(self.datetime)
                op_dt_parsed = date_parser.parse(self.op_date)

                # Prepare the INSERT statement
                insert_sql = """
				INSERT INTO damage (
					msg_no, date, handling, to_ics_position, to_location, to_name, to_contact,
					from_ics_position, from_location, from_name, from_contact, jurisdiction,
					address, unit_suite, type_structure, stories, own_rent,
					type_damage_flooding, type_damage_exterior, type_damage_structural, type_damage_other,
					basement, damage_class, tag, insurance, estimate, comments, contact_name, contact_phone,
					op_relay_rcvd, op_relay_sent, op_name, op_call, op_time
				) VALUES (
					%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
					%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
				) RETURNING id;
				"""

                # Execute the INSERT
                cursor.execute(
                    insert_sql,
                    (
                        self.msg_no,
                        dt_parsed,
                        self.handling,
                        self.to_ics_position,
                        self.to_location,
                        self.to_name,
                        self.to_contact,
                        self.from_ics_position,
                        self.from_location,
                        self.from_name,
                        self.from_contact,
                        self.jurisdiction,
                        self.address,
                        self.unit_suite if self.unit_suite else None,
                        self.type_structure,
                        self.stories,
                        self.own_rent,
                        self.type_damage_flooding,
                        self.type_damage_exterior,
                        self.type_damage_structural,
                        self.type_damage_other,
                        self.basement,
                        self.damage_class,
                        self.tag,
                        self.insurance,
                        self.estimate,
                        self.comments,
                        self.contact_name,
                        self.contact_phone,
                        self.op_relay_rcvd,
                        self.op_relay_sent,
                        self.op_name,
                        self.op_call.upper(),
                        op_dt_parsed,
                    ),
                )

                # Get the inserted record ID
                record_id = cursor.fetchone()[0]
                connection.commit()
                return record_id

        except Exception as e:
            connection.rollback()
            raise Exception(f"Failed to save damage assessment to database: {e}")


def retrieve_from_database(connection, op_call=None, start_time=None, end_time=None):
    """
    Retrieve DamageAssessment records from PostgreSQL database.

    Args:
                                    connection: psycopg2 database connection object
                                    op_call (str, optional): Filter by operator call sign (case insensitive)
                                    start_time (str, optional): Filter by datetime >= start_time (parseable datetime string)
                                    end_time (str, optional): Filter by datetime <= end_time (parseable datetime string)

    Returns:
                                    list: List of DamageAssessment instances

    Raises:
                                    Exception: If database operation fails
    """
    import psycopg2
    from dateutil import parser as date_parser

    try:
        with connection.cursor() as cursor:
            # Build the WHERE clause dynamically
            where_conditions = []
            params = []

            if op_call:
                where_conditions.append("UPPER(op_call) = UPPER(%s)")
                params.append(op_call)

            if start_time:
                start_dt = date_parser.parse(start_time)
                where_conditions.append("date >= %s")
                params.append(start_dt)

            if end_time:
                end_dt = date_parser.parse(end_time)
                where_conditions.append("date <= %s")
                params.append(end_dt)

            # Construct the query
            base_query = """
			SELECT id, msg_no, date, handling, to_ics_position, to_location, to_name, to_contact,
				   from_ics_position, from_location, from_name, from_contact, jurisdiction,
				   address, unit_suite, type_structure, stories, own_rent,
				   type_damage_flooding, type_damage_exterior, type_damage_structural, type_damage_other,
				   basement, damage_class, tag, insurance, estimate, comments, contact_name, contact_phone,
				   op_relay_rcvd, op_relay_sent, op_name, op_call, op_time
			FROM damage
			"""

            if where_conditions:
                query = base_query + " WHERE " + " AND ".join(where_conditions)
            else:
                query = base_query

            query += " ORDER BY date DESC"

            # Execute the query
            cursor.execute(query, params)
            records = cursor.fetchall()

            # Convert each record to a DamageAssessment instance
            assessments = []
            for record in records:
                # Create a dictionary for the DamageAssessment constructor
                assessment_dict = {
                    # Header fields (provide defaults since not in database)
                    "organization": "!SCCoPIFO!",
                    "form_file_name": "form-damage-assessment.html",
                    "form_version": "3.20-1.0",
                    # Main fields from database
                    "msg_no": record[1],
                    "datetime": record[
                        2
                    ].isoformat(),  # Convert timestamp to ISO string
                    "handling": record[3],
                    "to_ics_position": record[4],
                    "to_location": record[5],
                    "to_name": record[6],
                    "to_contact": record[7],
                    "from_ics_position": record[8],
                    "from_location": record[9],
                    "from_name": record[10],
                    "from_contact": record[11],
                    "jurisdiction": record[12],
                    "incident_name": "Retrieved from database",  # Default since not in DB
                    "address": record[13],
                    "unit_suite": record[14] if record[14] else "",
                    "type_structure": record[15],
                    "stories": record[16],
                    "own_rent": record[17],
                    "type_damage_flooding": record[18],
                    "type_damage_exterior": record[19],
                    "type_damage_structural": record[20],
                    "type_damage_other": record[21],
                    "basement": record[22],
                    "damage_class": record[23],
                    "tag": record[24],
                    "insurance": record[25],
                    "estimate": record[26],
                    "comments": record[27],
                    "contact_name": record[28],
                    "contact_phone": record[29],
                    "op_relay_rcvd": record[30],
                    "op_relay_sent": record[31],
                    "op_name": record[32],
                    "op_call": record[33],
                    "op_date": record[
                        34
                    ].isoformat(),  # Convert timestamp to ISO string
                }

                # Create and add the DamageAssessment instance
                assessment = DamageAssessment(assessment_dict)
                assessments.append(assessment)

            return assessments

    except Exception as e:
        raise Exception(f"Failed to retrieve damage assessments from database: {e}")


def parse_damage_assessment(message_text: str) -> "DamageAssessment":
    """
    Parse a structured text message into a DamageAssessment instance.

    Args:
                                    message_text (str): The formatted text message to parse

    Returns:
                                    DamageAssessment: Validated damage assessment instance

    Raises:
                                    ValueError: If message format is invalid or required fields are missing
                                    KeyError: If mandatory fields are missing from the parsed data
                                    TypeError: If field values cannot be converted to required types
    """

    try:
        # Parse the message into a raw dictionary
        raw_data = _parse_message_lines(message_text)

        # Extract header information from first three lines
        header_data = _parse_header_lines(message_text)
        raw_data.update(header_data)

        # Convert to DamageAssessment dictionary format
        assessment_dict = _convert_to_assessment_dict(raw_data)

        # Create and return the DamageAssessment instance
        return DamageAssessment(assessment_dict)

    except (ValueError, KeyError, TypeError) as e:
        raise ValueError(f"Failed to parse damage assessment message: {e}") from e
    except Exception as e:
        raise ValueError(
            f"Unexpected error parsing damage assessment message: {e}"
        ) from e


def _parse_message_lines(message_text: str) -> dict:
    """Parse message lines into a dictionary of name_prefix -> value."""
    lines = message_text.strip().split("\n")

    # Skip first 3 lines and last line
    if len(lines) < 5:
        raise ValueError("Message too short - must have at least 5 lines")

    data_lines = lines[3:-1]
    raw_data = {}

    for line_num, line in enumerate(data_lines, start=4):
        try:
            # Find the colon
            colon_pos = line.find(":")
            if colon_pos == -1:
                continue  # Skip lines without colons

            # Extract name prefix (alphanumeric part before colon, ignoring periods)
            prefix_part = line[:colon_pos]
            name_prefix = re.sub(r"[^a-zA-Z0-9]", "", prefix_part)

            if not name_prefix:
                continue  # Skip if no valid prefix

            # Find the opening bracket and extract value
            bracket_pos = line.find("[", colon_pos)
            if bracket_pos == -1:
                continue  # Skip lines without opening bracket

            # Extract value (everything after '[' until end or closing ']')
            value_start = bracket_pos + 1
            closing_bracket = line.find("]", value_start)
            if closing_bracket != -1:
                value = line[value_start:closing_bracket]
            else:
                value = line[value_start:]  # Take rest of line if no closing bracket

            raw_data[name_prefix] = value

        except Exception as e:
            raise ValueError(f"Error parsing line {line_num}: '{line}' - {e}")

    return raw_data


def _parse_header_lines(message_text: str) -> dict:
    """Parse header information from the first three lines."""
    lines = message_text.strip().split("\n")

    if len(lines) < 3:
        raise ValueError("Message must have at least 3 header lines")

    header_data = {}

    # Line 1: Organization (should be !SCCoPIFO!)
    line1 = lines[0].strip()
    header_data["organization"] = line1

    # Line 2: Form file name (starts with #T:)
    line2 = lines[1].strip()
    if not line2.startswith("#T:"):
        raise ValueError(f"Second line must start with '#T:', got '{line2}'")
    form_file = line2[3:].strip()  # Remove '#T:' and whitespace
    header_data["form_file_name"] = form_file

    # Line 3: Form version (starts with #V:)
    line3 = lines[2].strip()
    if not line3.startswith("#V:"):
        raise ValueError(f"Third line must start with '#V:', got '{line3}'")
    form_version = line3[3:].strip()  # Remove '#V:' and whitespace
    header_data["form_version"] = form_version

    return header_data


def _convert_to_assessment_dict(raw_data: dict) -> dict:
    """Convert raw parsed data to DamageAssessment dictionary format."""

    # Mapping from name_prefix to DamageAssessment dictionary key
    field_mapping = {
        "MsgNo": "msg_no",
        "1a": "date",  # Will be combined with time
        "1b": "time",  # Will be combined with date
        "5": "handling",
        "7a": "to_ics_position",
        "7b": "to_location",
        "7c": "to_name",
        "7d": "to_contact",
        "8a": "from_ics_position",
        "8b": "from_location",
        "8c": "from_name",
        "8d": "from_contact",
        "20": "jurisdiction",
        "21": "incident_name",
        "22": "address",
        "23": "unit_suite",
        "24": "type_structure",
        "25": "stories",
        "26": "own_rent",
        "27a": "type_damage_flooding",
        "27b": "type_damage_exterior",
        "27c": "type_damage_structural",
        "27d": "type_damage_other",
        "28": "basement",
        "29": "damage_class",
        "30": "tag",
        "31": "insurance",
        "32": "estimate",
        "33": "comments",
        "34": "contact_name",
        "35": "contact_phone",
        "OpRelayRcvd": "op_relay_rcvd",
        "OpRelaySent": "op_relay_sent",
        "OpName": "op_name",
        "OpCall": "op_call",
        "OpDate": "op_date",  # Will be combined with op_time
        "OpTime": "op_time",  # Will be combined with op_date
    }

    assessment_dict = {}

    # First, add header fields directly (they don't go through field mapping)
    header_fields = ["organization", "form_file_name", "form_version"]
    for field in header_fields:
        if field in raw_data:
            assessment_dict[field] = raw_data[field]

    # Map and convert basic fields
    for prefix, dict_key in field_mapping.items():
        if prefix in raw_data and dict_key not in [
            "date",
            "time",
            "op_date",
            "op_time",
        ]:
            value = raw_data[prefix].strip()
            assessment_dict[dict_key] = _convert_field_value(dict_key, value)

    # Handle datetime combination (date + time -> datetime)
    assessment_dict["datetime"] = _combine_datetime(
        raw_data.get("1a", ""), raw_data.get("1b", ""), "datetime"
    )

    # Handle op_date combination (OpDate + OpTime -> op_date)
    assessment_dict["op_date"] = _combine_datetime(
        raw_data.get("OpDate", ""), raw_data.get("OpTime", ""), "op_date"
    )

    # Add default values for commonly missing mandatory fields
    if "op_relay_rcvd" not in assessment_dict:
        assessment_dict["op_relay_rcvd"] = "N/A"
    if "op_relay_sent" not in assessment_dict:
        assessment_dict["op_relay_sent"] = "N/A"

    return assessment_dict


def _convert_field_value(field_name: str, value: str):
    """Convert field value to appropriate type based on field name."""

    # Handle empty/None values for unit_suite
    if field_name == "unit_suite" and value.lower() in ["none", "n/a", ""]:
        return ""

    # Handle case normalization for enumerated fields
    if field_name == "handling":
        return value.title()  # Convert "ROUTINE" -> "Routine"

    # Handle insurance field with Yes/No format
    if field_name == "insurance":
        value_lower = value.lower().strip()
        if value_lower in ["yes", "true", "1", "on"]:
            return True
        elif value_lower in ["no", "false", "0", "off", "", "n/a", "none"]:
            return False
        else:
            raise ValueError(f"insurance field must be 'Yes' or 'No', got '{value}'")

    # Handle other boolean fields
    boolean_fields = {
        "type_damage_flooding",
        "type_damage_exterior",
        "type_damage_structural",
        "type_damage_other",
        "basement",
    }
    if field_name in boolean_fields:
        return _convert_to_boolean(value)

    # Handle integer fields
    if field_name in ["stories", "estimate"]:
        try:
            return int(value)
        except ValueError:
            raise ValueError(f"Field '{field_name}' must be an integer, got '{value}'")

    # Default to string for all other fields
    return value


def _convert_to_boolean(value: str) -> bool:
    """Convert string value to boolean."""
    value_lower = value.lower().strip()

    true_values = {"checked", "true", "yes", "1", "on"}
    false_values = {"", "unchecked", "false", "no", "0", "off", "n/a", "none"}

    if value_lower in true_values:
        return True
    elif value_lower in false_values:
        return False
    else:
        raise ValueError(f"Cannot convert '{value}' to boolean")


def _combine_datetime(date_str: str, time_str: str, field_name: str) -> str:
    """Combine separate date and time strings into a single datetime string."""

    date_str = date_str.strip()
    time_str = time_str.strip()

    if not date_str and not time_str:
        raise ValueError(f"Both date and time components missing for {field_name}")

    if not date_str:
        raise ValueError(f"Date component missing for {field_name}")

    if not time_str:
        # If time is missing, use 00:00
        time_str = "00:00"

    # Combine date and time
    datetime_str = f"{date_str} {time_str}"

    # Validate that the combined string can be parsed
    try:
        from dateutil import parser as date_parser

        date_parser.parse(datetime_str)
        return datetime_str
    except Exception as e:
        raise ValueError(
            f"Invalid datetime format for {field_name}: '{datetime_str}' - {e}"
        )


sample_input_text = """
!SCCoPIFO!
#T: form-damage-assessment.html
#V: 3.20-1.0
MsgNo: [6EI-007M]
1a.: [09/22/2025]
1b.: [12:31]
5.: [ROUTINE]
7a.: [Damage/Safety Assessment Group]
8a.: [Developer]
7b.: [Palo Alto]
8b.: [Palo Alto]
7c.: [Bob Iannucci]
8c.: [Bob Iannucci]
7d.: [Bob]
8d.: [Bob]
20.: [Palo Alto]
21.: [Development test]
22.: [3540 South Court]
23.: [None]
24.: [Single Family]
25.: [2]
26.: [Own]
27a.: [checked]
28.: [N/A]
29.: [Affected]
30.: [Yellow]
31.: [No]
32.: [1000]
33.: [Comments here]
34.: [Bob Iannucci]
35.: [6507141200]
OpName: [Bob Iannucci]
OpCall: [W6EI]
OpDate: [09/24/2025]
OpTime: [17:53]
!/ADDON!
"""


DEFAULT_CFG = "config.json"


# When invoked, pass the --config, typically pointing to
# /etc/{installation-name}/config.json
def main():
    ap = argparse.ArgumentParser(description="meshtastic-client")
    ap.add_argument(
        "--config",
        default=DEFAULT_CFG,
        help=f"Path to config file (default: {DEFAULT_CFG})",
    )
    args = ap.parse_args()

    config_repo = CF.Config()  # singleton
    config_repo.load("main", args.config)
    config = config_repo.config("main")

    logger = build_logger(config["meshtastic"].get("log_level", "INFO"))
    logger.info("✅ [Meshtastic] Logging is active")

    database = DamageDB(config)

    a = parse_damage_assessment(sample_input_text)
    logger.info(a.to_json())
    logger.info("\n\n")
    logger.info(a.to_message_format())

    try:
        db = DamageDB(config)
        conn = db.conn
        a.save_to_database(conn)
        db.close()

    except KeyboardInterrupt:
        logger.info("\n🚨 [Damage] Exiting.")
    finally:
        if database is not None:
            database.close()


if __name__ == "__main__":
    main()
