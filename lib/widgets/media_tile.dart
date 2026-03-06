import 'package:flutter/material.dart';
import 'package:tv_radio/models/media_item.dart';

/// Custom widget for displaying a media item (TV channel or Radio station)
/// Optimized for TV remote navigation with clear focus indicators
class MediaTile extends StatelessWidget {
  final MediaItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const MediaTile({
    Key? key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onTap();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: item.logo != null
              ? (item.logo!.startsWith('assets/')
                    ? Image.asset(
                        item.logo!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.radio,
                            size: 40,
                            color: Colors.grey,
                          );
                        },
                      )
                    : Image.network(
                        item.logo!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.radio,
                            size: 40,
                            color: Colors.grey,
                          );
                        },
                      ))
              : Icon(
                  item.type == 'tv' ? Icons.tv_outlined : Icons.radio,
                  size: 40,
                  color: Colors.blueAccent,
                ),
          title: Text(
            item.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: item.group != null
              ? Text(
                  item.group!,
                  style: const TextStyle(fontSize: 14, color: Colors.white54),
                )
              : null,
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }
}
