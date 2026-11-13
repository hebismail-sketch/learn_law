$storePass = Read-Host "Enter the password for the keystore" -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePass))

keytool -genkeypair -v `
  -keystore "d:\learn_law\android\app\upload-keystore.jks" `
  -storetype JKS `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload `
  -storepass $plain -keypass $plain `
  -dname "CN=Miras, OU=Mobile, O=Miras, L=Cairo, S=Cairo, C=EG"

Remove-Variable plain
