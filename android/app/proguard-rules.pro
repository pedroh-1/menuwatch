# O app usa apenas o reconhecedor de texto latino do ML Kit. O plugin faz
# referência aos demais idiomas, que não são incluídos no pacote.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
