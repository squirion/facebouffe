# ML Kit Text Recognition bundles only the Latin script; the plugin references
# the other language recognizers, which R8 then can't find. We never use them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Google AI Edge SDK (on-device Gemini Nano) — keep its API surface.
-keep class com.google.ai.edge.aicore.** { *; }
-dontwarn com.google.ai.edge.aicore.**
