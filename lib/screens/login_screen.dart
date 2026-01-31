import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/baserow_service.dart';
import '../services/favorites_service.dart';
import '../services/watch_progress_service.dart';
import 'profile_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _baserowService = BaserowService();
  final _favoritesService = FavoritesService();
  final _watchProgressService = WatchProgressService();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  static const String _backgroundImage = 'assets/images/Login.png';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _formKey.currentState?.reset();
      _emailController.clear();
      _passwordController.clear();
      _nameController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> result;
      
      if (_isLogin) {
        result = await _baserowService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        result = await _baserowService.createAccount(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );
        
        // Se deu erro no cadastro, tenta fazer login (pode ter criado mas dado erro)
        if (result['success'] != true) {
          final loginResult = await _baserowService.login(
            _emailController.text.trim(),
            _passwordController.text,
          );
          if (loginResult['success'] == true) {
            result = loginResult;
          }
        }
      }

      if (!mounted) return;

      if (result['success'] == true) {
        // Salva dados do usuário
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setInt('userId', result['user']['id']);
        await prefs.setString('userName', result['user']['nome']);
        await prefs.setString('userEmail', result['user']['email']);
        await prefs.setString('userPassword', _passwordController.text);
        await prefs.setInt('userDias', result['user']['dias'] ?? 0);
        await prefs.setInt('userRestam', result['user']['restam'] ?? 0);
        
        // Salva dados do usuário para sincronização
        await prefs.setString('currentUser', json.encode(result['user']));

        // Carrega dados do Baserow (favoritos, minha lista, progresso)
        try {
          await _favoritesService.loadFromBaserow();
          await _watchProgressService.loadFromBaserow();
        } catch (e) {
          print('Erro ao carregar dados do usuário: $e');
        }

        if (!mounted) return;

        // Navega para seleção de perfil
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
        );
      } else {
        _showErrorSnackBar(result['message'] ?? 'Erro desconhecido');
      }
    } catch (e) {
      // Última tentativa: tenta fazer login caso a conta tenha sido criada
      try {
        final loginResult = await _baserowService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (loginResult['success'] == true && mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setInt('userId', loginResult['user']['id']);
          await prefs.setString('userName', loginResult['user']['nome']);
          await prefs.setString('userEmail', loginResult['user']['email']);
          await prefs.setString('userPassword', _passwordController.text);
          
          // Salva dados do usuário para sincronização
          await prefs.setString('currentUser', json.encode(loginResult['user']));
          
          // Carrega dados do Baserow
          try {
            await _favoritesService.loadFromBaserow();
            await _watchProgressService.loadFromBaserow();
          } catch (e) {
            print('Erro ao carregar dados do usuário: $e');
          }
          
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()),
          );
          return;
        }
      } catch (_) {}
      
      if (mounted) {
        _showErrorSnackBar('Erro de conexão. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Status bar transparente
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background fixo em toda a tela
          SizedBox(
            width: double.infinity,
            height: screenHeight,
            child: Image.asset(
              _backgroundImage,
              fit: BoxFit.cover,
            ),
          ),
          // Overlay gradiente fixo
          SizedBox(
            width: double.infinity,
            height: screenHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),
          // Conteúdo centralizado que sobe com o teclado
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(),
                            _buildHeader(),
                            const SizedBox(height: 10),
                            _buildForm(),
                            const SizedBox(height: 32),
                            _buildSubmitButton(),
                            const SizedBox(height: 20),
                            _buildToggleMode(),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo
        Image.asset(
          'assets/images/Logo.png',
          width: 250,
          height: 170,
          fit: BoxFit.contain,
        ),
        Transform.translate(
          offset: const Offset(0, -50),
          child: Text(
            _isLogin ? 'Bem-vindo de volta!' : 'Crie sua conta',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Nome (apenas no cadastro)
          if (!_isLogin) ...[
            _buildTextField(
              controller: _nameController,
              label: 'Seu nome de usuário',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Digite seu nome';
                }
                if (value.trim().length < 3) {
                  return 'Nome deve ter pelo menos 3 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],
          // Email
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Digite seu email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Email inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Senha
          _buildTextField(
            controller: _passwordController,
            label: 'Senha',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[500],
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Digite sua senha';
              }
              if (!_isLogin && value.length < 6) {
                return 'Senha deve ter pelo menos 6 caracteres';
              }
              return null;
            },
          ),
          // Confirmar senha (apenas no cadastro)
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Confirmar senha',
              icon: Icons.lock_outline,
              obscureText: _obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[500],
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirme sua senha';
                }
                if (value != _passwordController.text) {
                  return 'As senhas não coincidem';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: Colors.grey[400]),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        prefixIcon: Icon(icon, color: const Color(0xFF7C4DFF)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF252836),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF12CDD9),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.red[400]!,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.red[400]!,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C4DFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                _isLogin ? 'Entrar' : 'Criar Conta',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildToggleMode() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? 'Não tem uma conta?' : 'Já tem uma conta?',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: _toggleMode,
          child: Text(
            _isLogin ? 'Criar conta' : 'Entrar',
            style: const TextStyle(
              color: Color(0xFF12CDD9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

