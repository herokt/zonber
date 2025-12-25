import 'package:flutter/material.dart';

class Character {
  final String id;
  final String name;
  final Color color;
  final String description;
  final String? imagePath; // Optional path for sprite

  const Character({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
    this.imagePath,
  });
}

class CharacterData {
  static const List<Character> availableCharacters = [
    Character(
      id: 'neon_green',
      name: 'Neon Green',
      color: Color(0xFF45A29E),
      description: 'The classic Zonber operator.',
      imagePath: 'assets/images/characters/neon_green.png',
    ),
    Character(
      id: 'cyber_red',
      name: 'Cyber Red',
      color: Color(0xFFF21D1D),
      description: 'Aggressive and dangerous.',
    ),
    Character(
      id: 'electric_blue',
      name: 'Electric Blue',
      color: Color(0xFF1D8CF2),
      description: 'Fast as lightning.',
    ),
    Character(
      id: 'plasma_purple',
      name: 'Plasma Purple',
      color: Color(0xFFD91DF2),
      description: 'Mysterious energy.',
    ),
  ];

  static Character getCharacter(String id) {
    return availableCharacters.firstWhere(
      (c) => c.id == id,
      orElse: () => availableCharacters[0],
    );
  }
}
