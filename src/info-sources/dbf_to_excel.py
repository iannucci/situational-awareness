# Situational Awareness Application

# Copyright © 2025 by Bob Iannucci.  All rights reserved worldwide.

# Use this to extract geocoding data from a .dbf file

from dbfread import DBF
import pandas as pd

# Specify the path to your DBF file
dbf_file_path = "LocData.dbf"

# Load the DBF table
dbf_table = DBF(dbf_file_path)
df = pd.DataFrame(iter(dbf_table))
df.to_excel("LocData.xlsx", index=False, sheet_name="Sheet1")
