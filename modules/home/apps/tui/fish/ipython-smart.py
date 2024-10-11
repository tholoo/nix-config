# NOTE: quotes must be single quote for it to work

import glob
import os

import django
from django.conf import settings

if not settings.configured:
    settings_path = glob.glob(os.path.join(os.getcwd(), '*', 'settings.py'))[0]
    module_name = os.path.basename(os.path.dirname(settings_path))
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', f'{module_name}.settings')

django.setup()

from django.apps import apps
from django.conf import settings
from django.db.models import *

# Automatically import all models
local_dict = locals()
for model_class in apps.get_models():
    local_dict[model_class.__name__] = model_class

# Clean up namespace
del local_dict, apps, os, glob

try:
    from yekta_config import crypto
except Exception:
    pass

import datetime
from datetime import timedelta, date
from collections import defaultdict

from django.db import connection as django_db_connection

# hold queries
django_db_connection.force_debug_cursor = True

try:
    from pygments import highlight
    from pygments.formatters import TerminalFormatter
    from pygments.lexers import PostgresLexer
    from sqlparse import format

    def show_sql(number: int = 1):
        query, query_time = django_db_connection.queries[-number].values()
        formatted = format(query, reindent=True)

        print(query_time)
        print(highlight(formatted, PostgresLexer(), TerminalFormatter()))

except Exception:

    def show_sql(number: int = 1):
        query, query_time = django_db_connection.queries[-number].values()
        print(query_time)
        print(query)

