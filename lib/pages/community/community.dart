import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import '../../Class Models/social model.dart';
import '../../Class Models/user.dart';
import 'dart:async';


enum SortBy { hot, newest, top, rising }
enum TimeFilter { hour, day, week, month, year, all }

class SocialScreen extends StatefulWidget {
  final UserModel currentUser;
  final PostModel? temppost;

  const SocialScreen({Key? key, required this.currentUser, this.temppost}) : super(key: key);

  @override
  _SocialScreenState createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _postController = TextEditingController();
  SortBy _sortBy = SortBy.hot;
  TimeFilter _timeFilter = TimeFilter.all;
  bool _showFilters = false;


  static const Color Orange = Color(0xFFFF4500);
  static const Color Blue = Color(0xFF0079D3);
  static const Color Gray = Color(0xFF878A8C);
  static const Color LightGray = Color(0xFFF6F7F8);

  @override
  void initState() {
    super.initState();
    if (widget.temppost != null) {
      _firestore.collection('social').doc('temp_post').set(widget.temppost!.toJson());
    }
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
      backgroundColor: LightGray,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_showFilters) _buildFiltersSection(),
          _buildCreatePostSection(),
          Expanded(child: _buildPostsList()),
        ],
      ),

    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: Orange, shape: BoxShape.circle),
            child: const Icon(Icons.language, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          const Text('Community', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_showFilters ? Icons.tune : Icons.tune_outlined, color: Gray),
          onPressed: () => setState(() => _showFilters = !_showFilters),
        ),
        IconButton(icon: const Icon(Icons.more_vert, color: Gray), onPressed: () {}),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _buildSortChips(),
          if (_sortBy == SortBy.top) ...[
            const SizedBox(height: 12),
            _buildTimeChips(),
          ],
        ],
      ),
    );
  }

  Widget _buildSortChips() {
    final sortOptions = [
      ('🔥 Hot', SortBy.hot),
      ('🆕 New', SortBy.newest),
      ('⬆️ Top', SortBy.top),
      ('📈 Rising', SortBy.rising),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sortOptions
            .map((option) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _buildChip(
            option.$1,
            _sortBy == option.$2,
                () => setState(() => _sortBy = option.$2),
            Blue,
          ),
        ))
            .toList(),
      ),
    );
  }

  Widget _buildTimeChips() {
    final timeOptions = [
      ('Hour', TimeFilter.hour),
      ('Day', TimeFilter.day),
      ('Week', TimeFilter.week),
      ('Month', TimeFilter.month),
      ('Year', TimeFilter.year),
      ('All', TimeFilter.all),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: timeOptions
            .map((option) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _buildChip(
            option.$1,
            _timeFilter == option.$2,
                () => setState(() => _timeFilter = option.$2),
            Orange,
          ),
        ))
            .toList(),
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap, Color activeColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? activeColor : Gray.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Gray,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePostSection() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Orange,
            backgroundImage: widget.currentUser.profileImageUrl.isNotEmpty
                ? NetworkImage(widget.currentUser.profileImageUrl)
                : null,
            child: widget.currentUser.profileImageUrl.isEmpty
                ? Text(widget.currentUser.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 14))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _showCreatePostDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Gray.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Create Post', style: TextStyle(color: Gray, fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(onPressed: _showCreatePostDialog, icon: const Icon(Icons.image_outlined, color: Gray)),
          IconButton(onPressed: _showCreatePostDialog, icon: const Icon(Icons.link, color: Gray)),
        ],
      ),
    );
  }

  Widget _buildPostsList() {
    return StreamBuilder<List<QuerySnapshot>>(
      stream: _getCombinedPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Orange));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        List<PostModel> allPosts = [];

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          // temp posts (show first)
          for (var doc in snapshot.data![0].docs) {
            try {
              final post = PostModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
              allPosts.add(post);
            } catch (e) {
              // Skip invalid posts
            }
          }

          // regular posts
          for (var doc in snapshot.data![1].docs) {
            try {
              final post = PostModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
              allPosts.add(post);
            } catch (e) {
              // Skip invalid posts
            }
          }
        }

        if (allPosts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.language, size: 64, color: Gray),
                SizedBox(height: 16),
                Text('No posts yet', style: TextStyle(color: Gray)),
              ],
            ),
          );
        }

        // filters and sorting to regular posts only (keep temp posts at top)
        final tempPosts = allPosts.where((post) => post.temp == true).toList();
        var regularPosts = allPosts.where((post) => post.temp != true).toList();

        regularPosts = _applyTimeFilter(regularPosts);
        regularPosts = _applySorting(regularPosts);

        final finalPosts = [...tempPosts, ...regularPosts];

        return ListView.builder(
          itemCount: finalPosts.length,
          itemBuilder: (context, index) => _buildPostCard(finalPosts[index]),
        );
      },
    );
  }

  Stream<List<QuerySnapshot>> _getCombinedPostsStream() {
    final tempStream = _firestore
        .collection('social')
        .where('temp', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();

    final regularStream = _firestore
        .collection('social')
        .where('temp', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Rx.combineLatest2(
      tempStream,
      regularStream,
          (QuerySnapshot a, QuerySnapshot b) => [a, b],
    );
  }

  Widget _buildPostCard(PostModel post) {
    final isUpvoted = post.upvotes.contains(widget.currentUser.id);
    final upvoteCount = post.upvotes.length;

    return Container(
      color:(!post.temp) ? Colors.white :Colors.red.withOpacity(0.2),
      margin: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vote section
            _buildVoteSection(post.id, isUpvoted, upvoteCount),
            // Post content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPostMetadata(post),
                    const SizedBox(height: 8),
                    Text(post.content, style: const TextStyle(fontSize: 14, color: Colors.black, height: 1.4)),
                    const SizedBox(height: 12),
                    _buildActionButtons(post),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteSection(String postId, bool isUpvoted, int upvoteCount) {
    return Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _toggleUpvote(postId, isUpvoted),
            child: Icon(Icons.keyboard_arrow_up, color: isUpvoted ? Orange : Gray, size: 24),
          ),
          Text(
            _formatVoteCount(upvoteCount),
            style: TextStyle(color: isUpvoted ? Orange : Gray, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const Icon(Icons.keyboard_arrow_down, color: Gray, size: 24),
        ],
      ),
    );
  }

  Widget _buildPostMetadata(PostModel post) {
    return Row(
      children: [
        const CircleAvatar(radius: 8, backgroundColor: Orange, child: Icon(Icons.language, color: Colors.white, size: 12)),
        const SizedBox(width: 4),
        const Text('r/social', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black)),
        Text(' • Posted by u/${post.userName} • ${_formatDateTime(post.createdAt)}',
            style: const TextStyle(color: Gray, fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButtons(PostModel post) {
    return Row(
      children: [
        _buildActionButton(Icons.mode_comment_outlined, '${post.commentCount} Comments', () => _showCommentsDialog(post)),
        const SizedBox(width: 16),
        _buildActionButton(Icons.share_outlined, 'Share', () {}),
        const SizedBox(width: 16),
        _buildActionButton(Icons.bookmark_border, 'Save', () {}),
        const Spacer(),
        IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz, color: Gray, size: 20)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Gray, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Gray, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showCreatePostDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Create a post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _createPost();
                    },
                    child: const Text('POST', style: TextStyle(color: Blue, fontWeight: FontWeight.w600)),
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
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Blue)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods
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
        posts.sort((a, b) {
          final aAge = DateTime.now().difference(a.createdAt).inHours;
          final bAge = DateTime.now().difference(b.createdAt).inHours;
          if (aAge > 24 || bAge > 24) return 0;
          final aScore = a.upvotes.length / (aAge + 1);
          final bScore = b.upvotes.length / (bAge + 1);
          return bScore.compareTo(aScore);
        });
        break;
    }
    return posts;
  }

  String _formatVoteCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  String _formatDateTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'now';
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
        temp: false,
      );
      final postData = post.toJson();
      postData['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('social').add(postData);
      _postController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!'), backgroundColor: Orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating post: $e')));
      }
    }
  }

  Future<void> _toggleUpvote(String postId, bool isCurrentlyUpvoted) async {
    try {
      final postRef = _firestore.collection('social').doc(postId);
      if (isCurrentlyUpvoted) {
        await postRef.update({'upvotes': FieldValue.arrayRemove([widget.currentUser.id])});
      } else {
        await postRef.update({'upvotes': FieldValue.arrayUnion([widget.currentUser.id])});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating upvote: $e')));
      }
    }
  }

  void _showCommentsDialog(PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(post: post, currentUser: widget.currentUser),
    );
  }
}

// Comments Bottom Sheet (keeping the existing implementation)
class CommentsBottomSheet extends StatefulWidget {
  final PostModel post;
  final UserModel currentUser;

  const CommentsBottomSheet({Key? key, required this.post, required this.currentUser}) : super(key: key);

  @override
  _CommentsBottomSheetState createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  String? _replyingTo;

  static const Color Orange = Color(0xFFFF4500);
  static const Color Blue = Color(0xFF0079D3);
  static const Color Gray = Color(0xFF878A8C);

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
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Gray)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildCommentsList(scrollController)),
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
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Orange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.comment_outlined, size: 48, color: Gray),
                SizedBox(height: 16),
                Text('No comments yet', style: TextStyle(color: Gray)),
                Text('Be the first to share what you think!', style: TextStyle(color: Gray, fontSize: 12)),
              ],
            ),
          );
        }

        List<CommentModel> comments = snapshot.data!.docs
            .map((doc) {
          try {
            return CommentModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
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
          repliesMap.putIfAbsent(comment.parentCommentId!, () => []).add(comment);
        }

        return ListView.builder(
          controller: scrollController,
          itemCount: parentComments.length,
          itemBuilder: (context, index) {
            final comment = parentComments[index];
            final replies = repliesMap[comment.id] ?? [];
            return Column(
              children: [
                _buildCommentCard(comment, 0),
                ...replies.map((reply) => _buildCommentCard(reply, 1)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCommentCard(CommentModel comment, int depth) {
    final isUpvoted = comment.upvotes.contains(widget.currentUser.id);

    return Container(
      margin: EdgeInsets.only(left: depth * 16.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _toggleCommentUpvote(comment.id, isUpvoted),
                    child: Icon(Icons.keyboard_arrow_up, color: isUpvoted ? Orange : Gray, size: 20),
                  ),
                  Text(
                    comment.upvotes.length.toString(),
                    style: TextStyle(color: isUpvoted ? Orange : Gray, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: Gray, size: 20),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('u/${comment.userName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black)),
                        Text(' • ${_formatDateTime(comment.createdAt)}', style: const TextStyle(color: Gray, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(comment.content, style: const TextStyle(fontSize: 14, color: Colors.black, height: 1.3)),
                    const SizedBox(height: 8),
                    if (depth == 0)
                      GestureDetector(
                        onTap: () => _startReply(comment.id, comment.userName),
                        child: const Text('Reply', style: TextStyle(color: Gray, fontSize: 12, fontWeight: FontWeight.w600)),
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

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Column(
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Row(
                children: [
                  Text('Replying to $_replyingTo', style: const TextStyle(fontSize: 12, color: Blue)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _replyingTo = null),
                    child: const Icon(Icons.close, size: 16, color: Blue),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Gray.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Blue)),
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
                  decoration: const BoxDecoration(color: Blue, shape: BoxShape.circle),
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

      final commentData = comment.toJson();
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
            .update({'replyCount': FieldValue.increment(1)});
      }

      _commentController.clear();
      setState(() => _replyingTo = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error posting comment: $e')));
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
        await commentRef.update({'upvotes': FieldValue.arrayRemove([widget.currentUser.id])});
      } else {
        await commentRef.update({'upvotes': FieldValue.arrayUnion([widget.currentUser.id])});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating upvote: $e')));
      }
    }
  }

  void _startReply(String commentId, String userName) {
    setState(() => _replyingTo = commentId);
  }

  String _formatDateTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'now';
  }
}