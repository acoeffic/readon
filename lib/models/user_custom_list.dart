import 'package:flutter/material.dart';
import '../data/icon_options.dart';
import 'book.dart';

class UserCustomList {
  final int id;
  final String userId;
  final String title;
  final String iconName;
  final String gradientColor;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<Book> books;

  UserCustomList({
    required this.id,
    required this.userId,
    required this.title,
    this.iconName = 'book-open',
    this.gradientColor = '#7FA497',
    this.isPublic = false,
    required this.createdAt,
    this.updatedAt,
    this.books = const [],
  });

  factory UserCustomList.fromJson(Map<String, dynamic> json,
      {List<Book>? books}) {
    return UserCustomList(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      iconName: json['icon_name'] as String? ?? 'book-open',
      gradientColor: json['gradient_color'] as String? ?? '#7FA497',
      isPublic: json['is_public'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      books: books ?? const [],
    );
  }

  Map<String, dynamic> toInsert() {
    return {
      'title': title,
      'icon_name': iconName,
      'gradient_color': gradientColor,
      'is_public': isPublic,
    };
  }

  int get bookCount => books.length;
  IconData get icon => mapLucideIconName(iconName);
  List<Color> get gradientColors => generateGradientFromHex(gradientColor);

  UserCustomList copyWith({
    String? title,
    String? iconName,
    String? gradientColor,
    bool? isPublic,
    List<Book>? books,
  }) {
    return UserCustomList(
      id: id,
      userId: userId,
      title: title ?? this.title,
      iconName: iconName ?? this.iconName,
      gradientColor: gradientColor ?? this.gradientColor,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
      updatedAt: updatedAt,
      books: books ?? this.books,
    );
  }
}
