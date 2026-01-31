import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'baserow_service.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorites';
  static const String _myListKey = 'my_list';
  static const String _userIdKey = 'user_id';
  
  final BaserowService _baserowService = BaserowService();

  // Obter ID do usuário logado
  Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('currentUser');
    if (userJson != null) {
      final user = json.decode(userJson);
      return user['id'] as int?;
    }
    return null;
  }

  // Sincronizar com Baserow (chamado após cada alteração)
  Future<void> _syncToBaserow() async {
    final userId = await _getUserId();
    if (userId != null) {
      final favorites = await getFavorites();
      final myList = await getMyList();
      
      // Sincroniza em background (não bloqueia a UI)
      _baserowService.syncFavorites(userId, favorites);
      _baserowService.syncMyList(userId, myList);
    }
  }

  // Carregar dados do Baserow (chamado no login)
  Future<void> loadFromBaserow() async {
    final userId = await _getUserId();
    
    if (userId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Busca favoritos do Baserow
        final favorites = await _baserowService.getFavorites(userId);
        await prefs.setStringList(_favoritesKey, favorites);
        
        // Busca minha lista do Baserow
        final myList = await _baserowService.getMyList(userId);
        await prefs.setStringList(_myListKey, myList);
      } catch (e) {
        print('Erro ao carregar dados do Baserow: $e');
      }
    }
  }

  // Adicionar/Remover dos Favoritos
  Future<bool> toggleFavorite(int contentId, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    
    final key = '${type}_$contentId';
    if (favorites.contains(key)) {
      favorites.remove(key);
    } else {
      favorites.add(key);
    }
    
    final success = await prefs.setStringList(_favoritesKey, favorites);
    if (success) {
      _syncToBaserow(); // Sincroniza em background
    }
    return success;
  }

  // Verificar se está nos Favoritos
  Future<bool> isFavorite(int contentId, String type) async {
    final favorites = await getFavorites();
    return favorites.contains('${type}_$contentId');
  }

  // Obter todos os Favoritos
  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  // Adicionar/Remover da Minha Lista
  Future<bool> toggleMyList(int contentId, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final myList = await getMyList();
    
    final key = '${type}_$contentId';
    if (myList.contains(key)) {
      myList.remove(key);
    } else {
      myList.add(key);
    }
    
    final success = await prefs.setStringList(_myListKey, myList);
    if (success) {
      _syncToBaserow(); // Sincroniza em background
    }
    return success;
  }

  // Verificar se está na Minha Lista
  Future<bool> isInMyList(int contentId, String type) async {
    final myList = await getMyList();
    return myList.contains('${type}_$contentId');
  }

  // Obter toda a Minha Lista
  Future<List<String>> getMyList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_myListKey) ?? [];
  }
}
