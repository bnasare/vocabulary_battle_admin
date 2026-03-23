import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/user_model.dart';

class OpponentSelector extends StatefulWidget {
  final String title;
  final String hintText;
  final List<UserModel> opponents;
  final String? selectedOpponentId;
  final Function(String?) onSelectionChanged;
  final VoidCallback? onInfoTap;

  const OpponentSelector({
    super.key,
    required this.title,
    required this.hintText,
    required this.opponents,
    required this.selectedOpponentId,
    required this.onSelectionChanged,
    this.onInfoTap,
  });

  @override
  State<OpponentSelector> createState() => _OpponentSelectorState();
}

class _OpponentSelectorState extends State<OpponentSelector> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<UserModel> _filteredOpponents = [];
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _updateTextField();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(OpponentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedOpponentId != oldWidget.selectedOpponentId) {
      _updateTextField();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _updateTextField() {
    if (widget.selectedOpponentId != null) {
      final selectedOpponent = widget.opponents.firstWhere(
        (opponent) => opponent.uid == widget.selectedOpponentId,
        orElse: () => widget.opponents.first,
      );
      _textController.text = selectedOpponent.displayName;
    } else {
      _textController.text = '';
    }
  }

  void _onFocusChange() {
    setState(() {
      _isActive = _focusNode.hasFocus;
      // When focused, show all available options
      if (_isActive) {
        _filterOpponents(_textController.text);
      }
    });
  }

  void _filterOpponents(String query) {
    final filtered = widget.opponents
        .where(
          (opponent) =>
              opponent.displayName
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              opponent.email.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    setState(() {
      _filteredOpponents = filtered;
    });
  }

  void _selectOpponent(UserModel opponent) {
    setState(() {
      _textController.text = opponent.displayName;
      widget.onSelectionChanged(opponent.uid);
      _isActive = false;
      _focusNode.unfocus();
    });
  }

  void _clearSelection() {
    setState(() {
      _textController.clear();
      widget.onSelectionChanged(null);
      _filterOpponents('');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.onInfoTap != null)
              GestureDetector(
                onTap: widget.onInfoTap,
                child: const Icon(
                  CupertinoIcons.info_circle,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Autocomplete text field
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              TextField(
                controller: _textController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  border: InputBorder.none,
                  suffixIcon: _textController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: _clearSelection,
                          child: Icon(
                            CupertinoIcons.clear_circled,
                            size: 20,
                            color: Colors.grey.shade500,
                          ),
                        )
                      : const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                  constraints: const BoxConstraints(
                    maxHeight: 50,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.0,
                ),
                onChanged: (value) {
                  _filterOpponents(value);
                  // Clear selection if text doesn't match any opponent
                  if (value.isEmpty) {
                    widget.onSelectionChanged(null);
                  }
                },
              ),

              // Show suggestions when active
              if (_isActive && _filteredOpponents.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filteredOpponents.length,
                      itemBuilder: (context, index) {
                        final opponent = _filteredOpponents[index];
                        return InkWell(
                          onTap: () => _selectOpponent(opponent),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: opponent.photoURL != null
                                      ? NetworkImage(opponent.photoURL!)
                                      : null,
                                  child: opponent.photoURL == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 16,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        opponent.displayName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        opponent.email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
