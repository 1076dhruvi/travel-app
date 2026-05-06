import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:typed_data';
class EncryptionService {
  // ⚠️ In production, store this key in Flutter Secure Storage
  // For simplicity, we use a fixed key here (32 chars = 256-bit AES)
  static const String _keyString = 'MyTravelApp32CharSecretKey123456';
  static const String _ivString = 'MyTravelAppIV123'; // 16 chars

  final enc.Key _key;
  final enc.IV _iv;
  late final enc.Encrypter _encrypter;

  EncryptionService()
      : _key = enc.Key.fromUtf8(_keyString),
        _iv = enc.IV.fromUtf8(_ivString) {
    _encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
  }

  /// Encrypts a file and saves it to app documents directory.
  /// Returns the path of the encrypted file.
  Future<String> encryptAndSaveFile(
      String sourcePath, String tripId) async {
    final File sourceFile = File(sourcePath);
    final Uint8List fileBytes = await sourceFile.readAsBytes();

    // Encrypt
    final enc.Encrypted encrypted = _encrypter.encryptBytes(fileBytes, iv: _iv);

    // Save to app directory
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String vaultDir = path.join(appDir.path, 'vault', tripId);
    await Directory(vaultDir).create(recursive: true);

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String encryptedFileName = 'doc_$timestamp.enc';
    final String encryptedFilePath = path.join(vaultDir, encryptedFileName);

    final File encryptedFile = File(encryptedFilePath);
    await encryptedFile.writeAsBytes(encrypted.bytes);

    return encryptedFilePath;
  }

  /// Decrypts an encrypted file and returns the decrypted bytes.
  Future<Uint8List> decryptFile(String encryptedFilePath) async {
    final File encryptedFile = File(encryptedFilePath);
    final Uint8List encryptedBytes = await encryptedFile.readAsBytes();

    final enc.Encrypted encrypted = enc.Encrypted(encryptedBytes);
    final List<int> decryptedBytes =
    _encrypter.decryptBytes(encrypted, iv: _iv);

    return Uint8List.fromList(decryptedBytes);
  }

  /// Decrypts to a temp file for viewing, returns temp file path.
  Future<String> decryptToTempFile(
      String encryptedFilePath, String originalName) async {
    final Uint8List decryptedBytes = await decryptFile(encryptedFilePath);

    final Directory tempDir = await getTemporaryDirectory();
    final String tempFilePath = path.join(tempDir.path, originalName);

    final File tempFile = File(tempFilePath);
    await tempFile.writeAsBytes(decryptedBytes);

    return tempFilePath;
  }
  Future<String> encryptAndSaveBytes(
      Uint8List bytes,
      String fileName,
      String tripId,
      ) async {
    final encData = _encrypter.encryptBytes(bytes, iv: _iv);

    final dir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory('${dir.path}/vault/$tripId');

    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }

    final filePath =
        '${vaultDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName.enc';

    final file = File(filePath);
    await file.writeAsBytes(encData.bytes);

    return file.path;
  }
}