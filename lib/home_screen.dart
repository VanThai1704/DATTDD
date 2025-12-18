import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Today\'s Schedule',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            _buildTodayEvent(context, 'Họp nhóm', '10:00 AM - 11:00 AM', Icons.group, Colors.orange),
            _buildTodayEvent(context, 'Làm bài tập lớn', '2:00 PM - 4:00 PM', Icons.assignment, Colors.blue),
            const SizedBox(height: 24.0),
            Text(
              'Upcoming Tasks',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            _buildUpcomingTask(context, 'Nộp báo cáo', 'Deadline: Tomorrow'),
            _buildUpcomingTask(context, 'Kiểm tra giữa kỳ', 'Deadline: May 25, 2024'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Action to add a new task or event
        },
        tooltip: 'Add New',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodayEvent(BuildContext context, String title, String time, IconData icon, Color color) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(time),
      ),
    );
  }

  Widget _buildUpcomingTask(BuildContext context, String title, String deadline) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: const Icon(Icons.task_alt, color: Colors.green, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(deadline),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          // Handle task tap
        },
      ),
    );
  }
}
