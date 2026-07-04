import 'package:flutter/material.dart';

import '../models/service_conversation.dart';
import '../models/service_message.dart';
import '../services/gig_repository.dart';

class ServiceConversationScreen extends StatefulWidget {
  const ServiceConversationScreen({
    super.key,
    required this.repository,
    required this.conversation,
  });

  final GigRepository repository;
  final ServiceConversation conversation;

  @override
  State<ServiceConversationScreen> createState() =>
      _ServiceConversationScreenState();
}

class _ServiceConversationScreenState extends State<ServiceConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  bool _checkingBlock = true;
  bool _otherUserBlocked = false;

  String? get _currentUid => widget.repository.currentUserUid;

  String get _otherUserUid => widget.conversation.providerUid == _currentUid
      ? widget.conversation.clientUid
      : widget.conversation.providerUid;

  String get _otherUserName => widget.conversation.providerUid == _currentUid
      ? widget.conversation.clientName
      : widget.conversation.providerName;

  @override
  void initState() {
    super.initState();
    _loadBlockState();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockState() async {
    final blocked = await widget.repository.isUserBlocked(_otherUserUid);
    if (!mounted) {
      return;
    }
    setState(() {
      _otherUserBlocked = blocked;
      _checkingBlock = false;
    });
  }

  Future<void> _toggleBlock() async {
    try {
      if (_otherUserBlocked) {
        await widget.repository.unblockUser(_otherUserUid);
      } else {
        await widget.repository.blockUser(
          userUid: _otherUserUid,
          userName: _otherUserName,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() => _otherUserBlocked = !_otherUserBlocked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _otherUserBlocked
                ? 'Blocked $_otherUserName.'
                : 'Unblocked $_otherUserName.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _reportConversation() async {
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report conversation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Harassment, spam, unsafe request...',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'Add anything the review team should know.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (submitted != true) {
      reasonController.dispose();
      detailsController.dispose();
      return;
    }

    try {
      await widget.repository.reportContent(
        contentType: 'conversation',
        targetId: widget.conversation.id,
        targetOwnerUid: _otherUserUid,
        targetOwnerName: _otherUserName,
        reason: reasonController.text,
        details: detailsController.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted for review.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      reasonController.dispose();
      detailsController.dispose();
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() => _isSending = true);
    try {
      await widget.repository.replyInConversation(
        conversationId: widget.conversation.id,
        text: text,
      );
      _messageController.clear();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = widget.repository.currentUserUid;
    final draft = _messageController.text.trim();
    final title = _otherUserName;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with $title'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') {
                _reportConversation();
              }
              if (value == 'block') {
                _toggleBlock();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Text('Report conversation'),
              ),
              PopupMenuItem(
                value: 'block',
                enabled: !_checkingBlock,
                child: Text(_otherUserBlocked ? 'Unblock user' : 'Block user'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_otherUserBlocked)
            MaterialBanner(
              content: Text(
                'You blocked $title. Unblock them to send new messages.',
              ),
              actions: [
                TextButton(
                  onPressed: _toggleBlock,
                  child: const Text('Unblock'),
                ),
              ],
            ),
          Expanded(
            child: StreamBuilder<List<ServiceMessage>>(
              stream: widget.repository
                  .watchConversationMessages(widget.conversation.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hello and share your date, location, and budget.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    final mine = message.senderUid == currentUid;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: mine
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.senderName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(message.text),
                            const SizedBox(height: 4),
                            Text(
                              '${message.sentAt.hour.toString().padLeft(2, '0')}:${message.sentAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF627D98),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_otherUserBlocked,
                      minLines: 1,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText:
                            'Write a friendly message with date, location, and budget...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _isSending || draft.isEmpty || _otherUserBlocked
                        ? null
                        : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
