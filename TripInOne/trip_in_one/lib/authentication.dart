import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'navigation.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!_validateForm()) return;

      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TabNavigationPage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _validateForm() {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      setState(() {
        _errorMessage = '請輸入有效的電子郵件地址';
      });
      return false;
    }
    if (_passwordController.text.isEmpty || _passwordController.text.length < 6) {
      setState(() {
        _errorMessage = '密碼長度必須至少為6個字符';
      });
      return false;
    }
    return true;
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return '找不到該用戶';
      case 'wrong-password':
        return '密碼錯誤';
      case 'invalid-email':
        return '無效的電子郵件格式';
      default:
        return '登入失敗：$code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '電子郵件',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密碼',
              ),
              obscureText: true,
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _handleLogin,
                    child: const Text('登入'),
                  ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                );
              },
              child: const Text('還沒有帳號？立即註冊'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!_validateForm()) return;

      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.pop(context); // 返回登入頁面
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('註冊成功！請登入')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _validateForm() {
    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      setState(() {
        _errorMessage = '請輸入有效的電子郵件地址';
      });
      return false;
    }
    if (_passwordController.text.isEmpty || _passwordController.text.length < 6) {
      setState(() {
        _errorMessage = '密碼長度必須至少為6個字符';
      });
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = '兩次輸入的密碼不相符';
      });
      return false;
    }
    return true;
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '該電子郵件已被註冊';
      case 'invalid-email':
        return '無效的電子郵件格式';
      case 'weak-password':
        return '密碼強度太弱';
      default:
        return '註冊失敗：$code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('註冊'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '電子郵件',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密碼',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: '確認密碼',
              ),
              obscureText: true,
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _handleRegister,
                    child: const Text('註冊'),
                  ),
          ],
        ),
      ),
    );
  }
}