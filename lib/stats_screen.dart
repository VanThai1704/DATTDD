import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'completed_tasks_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _totalFocusMinutes = 0;
  int _completedTasksCount = 0;
  int _currentStreak = 0;
  int _coins = 0;
  int _streakFreezes = 0;
  int _pendingTasksCount = 0;
  int _overdueTasksCount = 0;
  double _productivityScore = 0;
  Map<int, int> _hourlyFocusData = {};

  Map<String, int> _weeklyData = {};
  bool _isLoading = true;
  String _viewMode = 'week'; // 'week', 'month', 'quarter'

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      // 1. Load User Stats
      final userDoc = await _firestore
          .collection('user_profile')
          .doc('default_user')
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _coins = data['coins'] ?? 0;
        _streakFreezes = data['streakFreezes'] ?? 0;
      }

      // 2. Focus Sessions
      final focusSnapshot = await _firestore.collection('focus_sessions').get();
      int totalMinutes = 0;
      Set<String> activeDays = {};
      Map<String, int> dailyFocus = {};

      for (var doc in focusSnapshot.docs) {
        final data = doc.data();
        final duration = data['duration'] as int? ?? 0;
        final date = data['date'] as String?;
        totalMinutes += duration;
        if (date != null) {
          activeDays.add(date);
          dailyFocus[date] = (dailyFocus[date] ?? 0) + duration;
        }
      }

      Map<String, int> weekly = {};
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final dayStr = DateFormat('yyyy-MM-dd').format(d);
        final label = DateFormat('E').format(d);
        weekly[label] = dailyFocus[dayStr] ?? 0;
      }

      // 3. Tasks Stats
      final taskSnapshot = await _firestore.collection('tasks').get();
      int completed = 0;
      int pending = 0;
      int overdue = 0;
      
      for (var doc in taskSnapshot.docs) {
        final data = doc.data();
        final isDone = data['isCompleted'] ?? false;
        final deadline = (data['deadlineDateTime'] as Timestamp).toDate();
        
        if (isDone) {
          completed++;
        } else if (deadline.isBefore(now)) {
          overdue++;
        } else {
          pending++;
        }
      }

      // 4. Hourly focus analysis
      Map<int, int> hourlyFocus = {};
      for (var doc in focusSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          final hour = createdAt.hour;
          final duration = data['duration'] as int? ?? 0;
          hourlyFocus[hour] = (hourlyFocus[hour] ?? 0) + duration;
        }
      }

      // 5. Productivity score (0-100)
      double score = 0;
      if (completed + pending + overdue > 0) {
        score = (completed / (completed + pending + overdue)) * 100;
      }
      score = (score + (_currentStreak * 2)).clamp(0, 100);

      // 6. Streak
      int streak = 0;
      DateTime checkDate = now;
      if (!activeDays.contains(todayStr))
        checkDate = now.subtract(const Duration(days: 1));
      while (activeDays.contains(DateFormat('yyyy-MM-dd').format(checkDate))) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }

      if (mounted) {
        setState(() {
          _totalFocusMinutes = totalMinutes;
          _completedTasksCount = completed;
          _pendingTasksCount = pending;
          _overdueTasksCount = overdue;
          _currentStreak = streak;
          _weeklyData = weekly;
          _productivityScore = score;
          _hourlyFocusData = hourlyFocus;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _buyFreeze() async {
    if (_coins >= 50) {
      await _firestore.collection('user_profile').doc('default_user').update({
        'coins': FieldValue.increment(-50),
        'streakFreezes': FieldValue.increment(1),
      });
      _loadAllStats();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bought Streak Freeze! ❄️')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not enough coins! 🪙')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: const Color(0xFF0F0F0F),
                  expandedHeight: 80,
                  flexibleSpace: const FlexibleSpaceBar(
                    title: Text(
                      'PERFORMANCE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        fontSize: 16,
                      ),
                    ),
                    centerTitle: true,
                  ),
                  pinned: true,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCoinWallet(),
                        const SizedBox(height: 24),
                        _buildProductivityScore(),
                        const SizedBox(height: 24),
                        _buildInsightCard(),
                        const SizedBox(height: 24),
                        _buildTaskPieChart(),
                        const SizedBox(height: 30),
                        _buildViewModeToggle(),
                        const SizedBox(height: 16),
                        const Text(
                          'FOCUS ACTIVITY',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildChart(),
                        const SizedBox(height: 30),
                        _buildBestFocusTime(),
                        const SizedBox(height: 30),
                        const Text(
                          'STREAK PROTECTION',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildShopItem(),
                        const SizedBox(height: 30),
                        _buildHistoryOpener(),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildHistoryOpener() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CompletedTasksScreen()),
      ),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
        ),
        child: const Row(
          children: [
            Icon(Icons.history, color: Colors.blueAccent),
            SizedBox(width: 16),
            Text(
              'VIEW FULL HISTORY',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinWallet() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Text(
            '$_coins COINS',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '$_streakFreezes FREEZES',
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductivityScore() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purpleAccent.withOpacity(0.2),
            Colors.blueAccent.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PRODUCTIVITY SCORE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${_productivityScore.toStringAsFixed(0)}/100',
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _productivityScore / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                _productivityScore > 70
                    ? Colors.greenAccent
                    : _productivityScore > 40
                        ? Colors.orangeAccent
                        : Colors.redAccent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getProductivityMessage(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _getProductivityMessage() {
    if (_productivityScore >= 80) return '🔥 Xuất sắc! Bạn đang rất năng suất!';
    if (_productivityScore >= 60) return '👍 Tốt! Hãy duy trì phong độ!';
    if (_productivityScore >= 40) return '💪 Ổn! Cố gắng thêm một chút!';
    return '📈 Hãy bắt đầu với những mục tiêu nhỏ!';
  }

  Widget _buildTaskPieChart() {
    final total = _completedTasksCount + _pendingTasksCount + _overdueTasksCount;
    if (total == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TASK BREAKDOWN',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: _completedTasksCount.toDouble(),
                          color: Colors.greenAccent,
                          title: '$_completedTasksCount',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        PieChartSectionData(
                          value: _pendingTasksCount.toDouble(),
                          color: Colors.blueAccent,
                          title: '$_pendingTasksCount',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        PieChartSectionData(
                          value: _overdueTasksCount.toDouble(),
                          color: Colors.redAccent,
                          title: '$_overdueTasksCount',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem('Hoàn thành', Colors.greenAccent),
                  const SizedBox(height: 8),
                  _buildLegendItem('Đang làm', Colors.blueAccent),
                  const SizedBox(height: 8),
                  _buildLegendItem('Quá hạn', Colors.redAccent),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildViewModeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildModeChip('TUẦN', 'week'),
        const SizedBox(width: 8),
        _buildModeChip('THÁNG', 'month'),
        const SizedBox(width: 8),
        _buildModeChip('QUÝ', 'quarter'),
      ],
    );
  }

  Widget _buildModeChip(String label, String mode) {
    final isSelected = _viewMode == mode;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.black : Colors.white70,
        ),
      ),
      selected: isSelected,
      onSelected: (s) => setState(() => _viewMode = mode),
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.white.withOpacity(0.05),
    );
  }

  Widget _buildBestFocusTime() {
    if (_hourlyFocusData.isEmpty) return const SizedBox();

    var sortedHours = _hourlyFocusData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final bestHour = sortedHours.first.key;
    final bestMinutes = sortedHours.first.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wb_sunny,
            color: Colors.orangeAccent,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BEST FOCUS TIME',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${bestHour.toString().padLeft(2, '0')}:00 - ${(bestHour + 1).toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$bestMinutes phút tập trung',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem(
            'STREAK',
            '$_currentStreak',
            Icons.local_fire_department,
            Colors.orange,
          ),
          _buildStatItem(
            'DONE',
            '$_completedTasksCount',
            Icons.check_circle,
            Colors.greenAccent,
          ),
          _buildStatItem(
            'FOCUS',
            '${_totalFocusMinutes}m',
            Icons.timer,
            Colors.blueAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String val, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white24,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          maxY:
              (_weeklyData.values.isNotEmpty
                      ? _weeklyData.values.reduce((a, b) => a > b ? a : b)
                      : 0)
                  .toDouble() +
              10,
          barGroups: _weeklyData.entries.map((e) {
            int index = _weeklyData.keys.toList().indexOf(e.key);
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: e.value.toDouble(),
                  color: Colors.blueAccent,
                  width: 12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, m) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _weeklyData.keys.elementAt(v.toInt()),
                    style: const TextStyle(color: Colors.white24, fontSize: 8),
                  ),
                ),
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildShopItem() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.ac_unit, color: Colors.blueAccent, size: 30),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STREAK FREEZE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Protect your streak if you miss a day.',
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _buyFreeze,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '50 🪙',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
