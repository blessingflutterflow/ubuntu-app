String formatTimestamp(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds  < 60)          return 'just now';
  if (diff.inMinutes  < 60)          return '${diff.inMinutes}m ago';
  if (diff.inHours    < 24)          return '${diff.inHours}h ago';
  if (diff.inDays     < 7)           return '${diff.inDays}d ago';
  return '${diff.inDays ~/ 7}w ago';
}

String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String formatNotifTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60)  return 'just now';
  if (diff.inMinutes < 60)  return '${diff.inMinutes}m';
  if (diff.inHours   < 24)  return '${diff.inHours}h';
  if (diff.inDays    < 7)   return '${diff.inDays}d';
  return '${diff.inDays ~/ 7}w';
}
