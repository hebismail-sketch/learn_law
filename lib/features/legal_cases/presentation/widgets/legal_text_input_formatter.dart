import 'package:flutter/services.dart';

import '../../../../core/legal_text.dart';

final TextInputFormatter legalTextInputFormatter =
    FilteringTextInputFormatter.deny(legalTextSymbolPattern);
