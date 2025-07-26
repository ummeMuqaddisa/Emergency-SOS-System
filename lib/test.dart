// Filter Options
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'Class Models/social model.dart';
import 'Class Models/user.dart';
enum SortBy { mostRecent, mostUpvoted }
enum TimeFilter { all, week, month, year }

class SocialMediaScreen extends StatefulWidget {
  final UserModel currentUser;

  const SocialMediaScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  _SocialMediaScreenState createState() => _SocialMediaScreenState();
}

class _SocialMediaScreenState extends State<SocialMediaScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _postController = TextEditingController();

  SortBy _sortBy = SortBy.mostRecent;
  TimeFilter _timeFilter = TimeFilter.all;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _postController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button press gracefully
        if (_showFilters) {
          setState(() {
            _showFilters = false;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Social Feed'),
          actions: [
            IconButton(
              icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_outlined),
              onPressed: () {
                setState(() {
                  _showFilters = !_showFilters;
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (_showFilters) _buildFilterSection(),
            _buildCreatePostSection(),
            Expanded(child: _buildPostsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sort By:', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              _buildFilterChip('Most Recent', _sortBy == SortBy.mostRecent, () {
                setState(() => _sortBy = SortBy.mostRecent);
              }),
              const SizedBox(width: 8),
              _buildFilterChip('Most Upvoted', _sortBy == SortBy.mostUpvoted, () {
                setState(() => _sortBy = SortBy.mostUpvoted);
              }),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Time Filter:', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              _buildFilterChip('All', _timeFilter == TimeFilter.all, () {
                setState(() => _timeFilter = TimeFilter.all);
              }),
              const SizedBox(width: 8),
              _buildFilterChip('Week', _timeFilter == TimeFilter.week, () {
                setState(() => _timeFilter = TimeFilter.week);
              }),
              const SizedBox(width: 8),
              _buildFilterChip('Month', _timeFilter == TimeFilter.month, () {
                setState(() => _timeFilter = TimeFilter.month);
              }),
              const SizedBox(width: 8),
              _buildFilterChip('Year', _timeFilter == TimeFilter.year, () {
                setState(() => _timeFilter = TimeFilter.year);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.blue,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePostSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: widget.currentUser.profileImageUrl.isNotEmpty
                ? NetworkImage(widget.currentUser.profileImageUrl)
                : null,
            child: widget.currentUser.profileImageUrl.isEmpty
                ? Text(widget.currentUser.name[0].toUpperCase())
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _postController,
              decoration: const InputDecoration(
                hintText: 'What\'s on your mind?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _createPost,
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Stream error: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No posts yet'));
        }

        List<PostModel> posts = snapshot.data!.docs
            .map((doc) {
          try {
            return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } catch (e) {
            print('Error parsing post: $e');
            return null;
          }
        })
            .where((post) => post != null)
            .cast<PostModel>()
            .toList();

        // Apply time filter
        posts = _applyTimeFilter(posts);

        // Apply sorting
        if (_sortBy == SortBy.mostUpvoted) {
          posts.sort((a, b) => b.upvotes.length.compareTo(a.upvotes.length));
        } else {
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) setState(() {});
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: posts.length,
            itemBuilder: (context, index) => _buildPostCard(posts[index]),
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getPostsStream() {
    return _firestore
        .collection('social')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  List<PostModel> _applyTimeFilter(List<PostModel> posts) {
    if (_timeFilter == TimeFilter.all) return posts;

    final now = DateTime.now();
    DateTime filterDate;

    switch (_timeFilter) {
      case TimeFilter.week:
        filterDate = now.subtract(const Duration(days: 7));
        break;
      case TimeFilter.month:
        filterDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case TimeFilter.year:
        filterDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        return posts;
    }

    return posts.where((post) => post.createdAt.isAfter(filterDate)).toList();
  }

  Widget _buildPostCard(PostModel post) {
    final isUpvoted = post.upvotes.contains(widget.currentUser.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: post.userProfileImage.isNotEmpty
                      ? NetworkImage(post.userProfileImage)
                      : null,
                  child: post.userProfileImage.isEmpty
                      ? Text(post.userName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDateTime(post.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.content),
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleUpvote(post.id, isUpvoted),
                  child: Row(
                    children: [
                      Icon(
                        isUpvoted ? Icons.arrow_upward : Icons.arrow_upward_outlined,
                        color: isUpvoted ? Colors.blue : Colors.grey,
                      ),
                      Text('${post.upvotes.length}'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _showCommentsDialog(post),
                  child: Row(
                    children: [
                      const Icon(Icons.comment_outlined, color: Colors.grey),
                      Text('${post.commentCount}'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty) return;

    try {
      final post = PostModel(
        id: '',
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        userProfileImage: widget.currentUser.profileImageUrl,
        content: _postController.text.trim(),
        createdAt: DateTime.now(),
        upvotes: [],
        commentCount: 0,
      );

      // Use server timestamp for better consistency
      final postData = post.toMap();
      postData['createdAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('social').add(postData);
      _postController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }
    }
  }

  Future<void> _toggleUpvote(String postId, bool isCurrentlyUpvoted) async {
    try {
      final postRef = _firestore.collection('social').doc(postId);

      if (isCurrentlyUpvoted) {
        await postRef.update({
          'upvotes': FieldValue.arrayRemove([widget.currentUser.id])
        });
      } else {
        await postRef.update({
          'upvotes': FieldValue.arrayUnion([widget.currentUser.id])
        });
      }
    } catch (e) {
      print('Error updating upvote: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating upvote: $e')),
        );
      }
    }
  }



  void _showCommentsDialog(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => CommentsBottomSheet(
        post: post,
        currentUser: widget.currentUser,
      ),
    ).then((_) {
      // Handle any cleanup when modal is dismissed
      if (mounted) {
        setState(() {});
      }
    });
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class CommentsBottomSheet extends StatefulWidget {
  final PostModel post;
  final UserModel currentUser;

  const CommentsBottomSheet({
    Key? key,
    required this.post,
    required this.currentUser,
  }) : super(key: key);

  @override
  _CommentsBottomSheetState createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  String? _replyingTo;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Comments',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Expanded(
                child: _buildCommentsList(scrollController),
              ),
              _buildCommentInput(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentsList(ScrollController scrollController) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('social')
          .doc(widget.post.id)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Comments stream error: ${snapshot.error}');
          return Center(child: Text('Error loading comments: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No comments yet. Be the first to comment!'),
            ),
          );
        }

        List<CommentModel> comments = snapshot.data!.docs
            .map((doc) {
          try {
            return CommentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } catch (e) {
            print('Error parsing comment: $e');
            return null;
          }
        })
            .where((comment) => comment != null)
            .cast<CommentModel>()
            .toList();

        // Separate parent comments and replies
        List<CommentModel> parentComments = comments.where((c) => c.parentCommentId == null).toList();
        Map<String, List<CommentModel>> repliesMap = {};

        for (var comment in comments.where((c) => c.parentCommentId != null)) {
          if (!repliesMap.containsKey(comment.parentCommentId)) {
            repliesMap[comment.parentCommentId!] = [];
          }
          repliesMap[comment.parentCommentId!]!.add(comment);
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) setState(() {});
          },
          child: ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: parentComments.length,
            itemBuilder: (context, index) {
              final comment = parentComments[index];
              final replies = repliesMap[comment.id] ?? [];

              return Column(
                children: [
                  _buildCommentCard(comment, false),
                  ...replies.map((reply) => _buildCommentCard(reply, true)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCommentCard(CommentModel comment, bool isReply) {
    final isUpvoted = comment.upvotes.contains(widget.currentUser.id);

    return Container(
      margin: EdgeInsets.only(
        left: isReply ? 32 : 16,
        right: 16,
        bottom: 8,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReply ? Colors.grey[50] : Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: comment.userProfileImage.isNotEmpty
                    ? NetworkImage(comment.userProfileImage)
                    : null,
                child: comment.userProfileImage.isEmpty
                    ? Text(comment.userName[0].toUpperCase(), style: const TextStyle(fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comment.content),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleCommentUpvote(comment.id, isUpvoted),
                child: Row(
                  children: [
                    Icon(
                      isUpvoted ? Icons.arrow_upward : Icons.arrow_upward_outlined,
                      color: isUpvoted ? Colors.blue : Colors.grey,
                      size: 18,
                    ),
                    Text('${comment.upvotes.length}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              if (!isReply) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _startReply(comment.id, comment.userName),
                  child: const Text(
                    'Reply',
                    style: TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text('Replying to $_replyingTo', style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: widget.currentUser.profileImageUrl.isNotEmpty
                    ? NetworkImage(widget.currentUser.profileImageUrl)
                    : null,
                child: widget.currentUser.profileImageUrl.isEmpty
                    ? Text(widget.currentUser.name[0].toUpperCase(), style: const TextStyle(fontSize: 12))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Write a comment...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _createComment,
                child: const Text('Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final comment = CommentModel(
        id: '',
        postId: widget.post.id,
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        userProfileImage: widget.currentUser.profileImageUrl,
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
        upvotes: [],
        parentCommentId: _replyingTo,
        replyCount: 0,
      );

      // Use server timestamp for better consistency
      final commentData = comment.toMap();
      commentData['createdAt'] = FieldValue.serverTimestamp();

      // Add comment to subcollection
      await _firestore
          .collection('social')
          .doc(widget.post.id)
          .collection('comments')
          .add(commentData);

      // Update post comment count
      await _firestore.collection('social').doc(widget.post.id).update({
        'commentCount': FieldValue.increment(1),
      });

      // If it's a reply, update parent comment reply count
      if (_replyingTo != null) {
        await _firestore
            .collection('social')
            .doc(widget.post.id)
            .collection('comments')
            .doc(_replyingTo)
            .update({
          'replyCount': FieldValue.increment(1),
        });
      }

      _commentController.clear();
      setState(() => _replyingTo = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted successfully!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error posting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
    }
  }

  Future<void> _toggleCommentUpvote(String commentId, bool isCurrentlyUpvoted) async {
    try {
      final commentRef = _firestore
          .collection('social')
          .doc(widget.post.id)
          .collection('comments')
          .doc(commentId);

      if (isCurrentlyUpvoted) {
        await commentRef.update({
          'upvotes': FieldValue.arrayRemove([widget.currentUser.id])
        });
      } else {
        await commentRef.update({
          'upvotes': FieldValue.arrayUnion([widget.currentUser.id])
        });
      }
    } catch (e) {
      print('Error updating comment upvote: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating upvote: $e')),
        );
      }
    }
  }

  void _startReply(String commentId, String userName) {
    setState(() {
      _replyingTo = commentId;
    });
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}