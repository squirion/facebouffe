# ML Kit Text Recognition bundles only the Latin script; the plugin references
# the other language recognizers, which R8 then can't find. We never use them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# MediaPipe LLM Inference (on-device Tier 1) — keep its API + native bindings.
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**
