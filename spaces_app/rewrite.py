import os
import re

files = [
    'lib/presentation/screens/spaces/space_detail_screen.dart',
    'lib/presentation/screens/spaces/file_version_history_screen.dart',
    'lib/presentation/screens/spaces/file_detail_screen.dart',
    'lib/presentation/screens/sharing/request_links_screen.dart',
    'lib/presentation/screens/search/search_screen.dart',
    'lib/presentation/screens/search/deep_search_screen.dart',
    'lib/presentation/screens/offline/offline_files_screen.dart',
    'lib/presentation/screens/auth/register_screen.dart',
    'lib/presentation/screens/auth/login_screen.dart',
    'lib/presentation/screens/ai/dropzone_screen.dart',
    'lib/presentation/screens/ai/ai_usage_screen.dart',
    'lib/presentation/screens/ai/ai_chat_screen.dart',
    'lib/presentation/screens/ai/ai_center_screen.dart'
]

import_pattern = re.compile(r"(import 'package:flutter/material\.dart';)")
# The buttons vary slightly. For example, some might have tooltips or different onPressed logic.
# Let's match more loosely.
button_pattern = re.compile(r'IconButton\(\s*icon:\s*const\s*Icon\(Icons\.arrow_back_ios_new_rounded,\s*size:\s*20\),[^)]*\)')

for f in files:
    if not os.path.exists(f): continue
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    if 'UnifiedBackButton' not in content:
        depth = len(f.split('/')) - 2
        rel_path = '../' * (depth - 1) + 'widgets/unified_back_button.dart'
        content = import_pattern.sub(r"\1\nimport '" + rel_path + r"';", content)

    content = button_pattern.sub('UnifiedBackButton()', content)
    
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
print('Done!')
