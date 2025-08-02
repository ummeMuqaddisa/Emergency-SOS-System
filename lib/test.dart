import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// Import your existing models
import 'Class Models/social model.dart';
import 'Class Models/user.dart';

enum SortBy { hot, newest, top, rising }
enum TimeFilter { hour, day, week, month, year, all }

class SocialScreen extends StatefulWidget {
  final UserModel currentUser;
  const SocialScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  _SocialScreenState createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _postController = TextEditingController();
  SortBy _sortBy = SortBy.hot;
  TimeFilter _timeFilter = TimeFilter.all;
  bool _showFilters = false;

  // Reddit color scheme
  static const Color redditOrange = Color(0xFFFF4500);
  static const Color redditBlue = Color(0xFF0079D3);
  static const Color redditGray = Color(0xFF878A8C);
  static const Color redditLightGray = Color(0xFFF6F7F8);
  static const Color redditDarkGray = Color(0xFF1A1A1B);

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: redditLightGray,
      appBar: _buildRedditAppBar(),
      body: Column(
        children: [
          if (_showFilters) _buildRedditFilterSection(),
          _buildRedditCreatePostSection(),
          Expanded(child: _buildRedditPostsList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildRedditAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: redditOrange,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.reddit, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          const Text(
            'r/social',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showFilters ? Icons.tune : Icons.tune_outlined,
            color: redditGray,
          ),
          onPressed: () {
            setState(() {
              _showFilters = !_showFilters;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: redditGray),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildRedditFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Sort options
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRedditSortChip('🔥 Hot', _sortBy == SortBy.hot, () {
                  setState(() => _sortBy = SortBy.hot);
                }),
                const SizedBox(width: 8),
                _buildRedditSortChip('🆕 New', _sortBy == SortBy.newest, () {
                  setState(() => _sortBy = SortBy.newest);
                }),
                const SizedBox(width: 8),
                _buildRedditSortChip('⬆️ Top', _sortBy == SortBy.top, () {
                  setState(() => _sortBy = SortBy.top);
                }),
                const SizedBox(width: 8),
                _buildRedditSortChip('📈 Rising', _sortBy == SortBy.rising, () {
                  setState(() => _sortBy = SortBy.rising);
                }),
              ],
            ),
          ),
          if (_sortBy == SortBy.top) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRedditTimeChip('Hour', _timeFilter == TimeFilter.hour, () {
                    setState(() => _timeFilter = TimeFilter.hour);
                  }),
                  const SizedBox(width: 8),
                  _buildRedditTimeChip('Day', _timeFilter == TimeFilter.day, () {
                    setState(() => _timeFilter = TimeFilter.day);
                  }),
                  const SizedBox(width: 8),
                  _buildRedditTimeChip('Week', _timeFilter == TimeFilter.week, () {
                    setState(() => _timeFilter = TimeFilter.week);
                  }),
                  const SizedBox(width: 8),
                  _buildRedditTimeChip('Month', _timeFilter == TimeFilter.month, () {
                    setState(() => _timeFilter = TimeFilter.month);
                  }),
                  const SizedBox(width: 8),
                  _buildRedditTimeChip('Year', _timeFilter == TimeFilter.year, () {
                    setState(() => _timeFilter = TimeFilter.year);
                  }),
                  const SizedBox(width: 8),
                  _buildRedditTimeChip('All', _timeFilter == TimeFilter.all, () {
                    setState(() => _timeFilter = TimeFilter.all);
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRedditSortChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? redditBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? redditBlue : redditGray.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : redditGray,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRedditTimeChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? redditOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? redditOrange : redditGray.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : redditGray,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRedditCreatePostSection() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: redditOrange,
            backgroundImage: widget.currentUser.profileImageUrl.isNotEmpty
                ? NetworkImage(widget.currentUser.profileImageUrl)
                : null,
            child: widget.currentUser.profileImageUrl.isEmpty
                ? Text(
              widget.currentUser.name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showCreatePostDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: redditGray.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Create Post',
                  style: TextStyle(
                    color: redditGray,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _showCreatePostDialog(),
            icon: const Icon(Icons.image_outlined, color: redditGray),
          ),
          IconButton(
            onPressed: () => _showCreatePostDialog(),
            icon: const Icon(Icons.link, color: redditGray),
          ),
        ],
      ),
    );
  }

  Widget _buildRedditPostsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: redditOrange));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.reddit, size: 64, color: redditGray),
                SizedBox(height: 16),
                Text('No posts yet', style: TextStyle(color: redditGray)),
              ],
            ),
          );
        }

        List<PostModel> posts = snapshot.data!.docs
            .map((doc) {
          try {
            return PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } catch (e) {
            return null;
          }
        })
            .where((post) => post != null)
            .cast<PostModel>()
            .toList();

        posts = _applyTimeFilter(posts);
        posts = _applySorting(posts);

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) => _buildRedditPostCard(posts[index]),
        );
      },
    );
  }

  Widget _buildRedditPostCard(PostModel post) {
    final isUpvoted = post.upvotes.contains(widget.currentUser.id);
    final upvoteCount = post.upvotes.length;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vote section
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _toggleUpvote(post.id, isUpvoted),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: isUpvoted ? redditOrange : redditGray,
                      size: 24,
                    ),
                  ),
                  Text(
                    _formatVoteCount(upvoteCount),
                    style: TextStyle(
                      color: isUpvoted ? redditOrange : redditGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {}, // Implement downvote if needed
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: redditGray,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            // Post content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post metadata
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: redditOrange,
                          child: const Icon(Icons.reddit, color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'r/social',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: redditGray, fontSize: 12)),
                        Text(
                          'Posted by u/${post.userName}',
                          style: const TextStyle(color: redditGray, fontSize: 12),
                        ),
                        const Text(' • ', style: TextStyle(color: redditGray, fontSize: 12)),
                        Text(
                          _formatDateTime(post.createdAt),
                          style: const TextStyle(color: redditGray, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Post content
                    Text(
                      post.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Action buttons
                    Row(
                      children: [
                        _buildRedditActionButton(
                          Icons.mode_comment_outlined,
                          '${post.commentCount} Comments',
                              () => _showCommentsDialog(post),
                        ),
                        const SizedBox(width: 16),
                        _buildRedditActionButton(
                          Icons.share_outlined,
                          'Share',
                              () {},
                        ),
                        const SizedBox(width: 16),
                        _buildRedditActionButton(
                          Icons.bookmark_border,
                          'Save',
                              () {},
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_horiz, color: redditGray, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedditActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: redditGray, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: redditGray,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Create a post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _createPost();
                    },
                    child: const Text(
                      'POST',
                      style: TextStyle(
                        color: redditBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _postController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'What are your thoughts?',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: redditBlue),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods
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
      case TimeFilter.hour:
        filterDate = now.subtract(const Duration(hours: 1));
        break;
      case TimeFilter.day:
        filterDate = now.subtract(const Duration(days: 1));
        break;
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

  List<PostModel> _applySorting(List<PostModel> posts) {
    switch (_sortBy) {
      case SortBy.hot:
      // Simple hot algorithm: upvotes / time factor
        posts.sort((a, b) {
          final aScore = a.upvotes.length / (DateTime.now().difference(a.createdAt).inHours + 1);
          final bScore = b.upvotes.length / (DateTime.now().difference(b.createdAt).inHours + 1);
          return bScore.compareTo(aScore);
        });
        break;
      case SortBy.newest:
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortBy.top:
        posts.sort((a, b) => b.upvotes.length.compareTo(a.upvotes.length));
        break;
      case SortBy.rising:
      // Simple rising algorithm: recent posts with growing upvotes
        posts.sort((a, b) {
          final aAge = DateTime.now().difference(a.createdAt).inHours;
          final bAge = DateTime.now().difference(b.createdAt).inHours;
          if (aAge > 24 || bAge > 24) return 0; // Only consider recent posts
          final aScore = a.upvotes.length / (aAge + 1);
          final bScore = b.upvotes.length / (bAge + 1);
          return bScore.compareTo(aScore);
        });
        break;
    }
    return posts;
  }

  String _formatVoteCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
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
      final postData = post.toMap();
      postData['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('social').add(postData);
      _postController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: redditOrange,
          ),
        );
      }
    } catch (e) {
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
      backgroundColor: Colors.transparent,
      builder: (context) => RedditCommentsBottomSheet(
        post: post,
        currentUser: widget.currentUser,
      ),
    );
  }
}

// Reddit-styled Comments Bottom Sheet
class RedditCommentsBottomSheet extends StatefulWidget {
  final PostModel post;
  final UserModel currentUser;

  const RedditCommentsBottomSheet({
    Key? key,
    required this.post,
    required this.currentUser,
  }) : super(key: key);

  @override
  _RedditCommentsBottomSheetState createState() => _RedditCommentsBottomSheetState();
}

class _RedditCommentsBottomSheetState extends State<RedditCommentsBottomSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  String? _replyingTo;

  static const Color redditOrange = Color(0xFFFF4500);
  static const Color redditBlue = Color(0xFF0079D3);
  static const Color redditGray = Color(0xFF878A8C);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: redditGray),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildCommentsList(scrollController)),
              _buildRedditCommentInput(),
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
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: redditOrange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.comment_outlined, size: 48, color: redditGray),
                SizedBox(height: 16),
                Text('No comments yet', style: TextStyle(color: redditGray)),
                Text('Be the first to share what you think!', style: TextStyle(color: redditGray, fontSize: 12)),
              ],
            ),
          );
        }

        List<CommentModel> comments = snapshot.data!.docs
            .map((doc) {
          try {
            return CommentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          } catch (e) {
            return null;
          }
        })
            .where((comment) => comment != null)
            .cast<CommentModel>()
            .toList();

        List<CommentModel> parentComments = comments.where((c) => c.parentCommentId == null).toList();
        Map<String, List<CommentModel>> repliesMap = {};
        for (var comment in comments.where((c) => c.parentCommentId != null)) {
          if (!repliesMap.containsKey(comment.parentCommentId)) {
            repliesMap[comment.parentCommentId!] = [];
          }
          repliesMap[comment.parentCommentId!]!.add(comment);
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: parentComments.length,
          itemBuilder: (context, index) {
            final comment = parentComments[index];
            final replies = repliesMap[comment.id] ?? [];
            return Column(
              children: [
                _buildRedditCommentCard(comment, 0),
                ...replies.map((reply) => _buildRedditCommentCard(reply, 1)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRedditCommentCard(CommentModel comment, int depth) {
    final isUpvoted = comment.upvotes.contains(widget.currentUser.id);

    return Container(
      margin: EdgeInsets.only(left: depth * 16.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vote section
            Container(
              width: 32,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _toggleCommentUpvote(comment.id, isUpvoted),
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      color: isUpvoted ? redditOrange : redditGray,
                      size: 20,
                    ),
                  ),
                  Text(
                    comment.upvotes.length.toString(),
                    style: TextStyle(
                      color: isUpvoted ? redditOrange : redditGray,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: redditGray,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // Comment content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Comment metadata
                    Row(
                      children: [
                        Text(
                          'u/${comment.userName}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: redditGray, fontSize: 12)),
                        Text(
                          _formatDateTime(comment.createdAt),
                          style: const TextStyle(color: redditGray, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Comment content
                    Text(
                      comment.content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Action buttons
                    if (depth == 0)
                      GestureDetector(
                        onTap: () => _startReply(comment.id, comment.userName),
                        child: const Text(
                          'Reply',
                          style: TextStyle(
                            color: redditGray,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedditCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: redditBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text(
                    'Replying to $_replyingTo',
                    style: const TextStyle(fontSize: 12, color: redditBlue),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(Icons.close, size: 16, color: redditBlue),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: redditGray.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: redditBlue),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _createComment,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: redditBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
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

      final commentData = comment.toMap();
      commentData['createdAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('social')
          .doc(widget.post.id)
          .collection('comments')
          .add(commentData);

      await _firestore.collection('social').doc(widget.post.id).update({
        'commentCount': FieldValue.increment(1),
      });

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
    } catch (e) {
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
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}