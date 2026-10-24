import os

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

for f in files:
    if not os.path.exists(f): continue
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    if 'unified_back_button.dart' not in content and 'UnifiedBackButton' in content:
        depth = len(f.split('/')) - 2
        rel_path = '../' * (depth - 1) + 'widgets/unified_back_button.dart'
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '" + rel_path + "';", 1)
        
        with open(f, 'w', encoding='utf-8') as file:
            file.write(content)
print('Done!')
