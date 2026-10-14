package com.jk.example

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required so the native
// plugin can show a BiometricPrompt, which needs a FragmentActivity host.
class MainActivity : FlutterFragmentActivity()
