#!/usr/bin/env ipython -i --no-banner --TerminalInteractiveShell.editing_mode=vi --TerminalInteractiveShell.emacs_bindings_in_vi_insert_mode=False

# import os

# Set the Django settings module if not already set
# os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'YOUR.SETTINGS.MODULE')

import django
# from django.conf import settings

# settings.configure()  # Only use if settings haven't been configured yet.
django.setup()

from django.db.models import Count, Max, Min, Q
from django.apps import apps

# Automatically import all models
local_dict = locals()
for model_class in apps.get_models():
    local_dict[model_class.__name__] = model_class

# Clean up namespace
del local_dict, apps
# del os
