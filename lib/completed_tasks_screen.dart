import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'models.dart';

class CompletedTasksScreen extends StatelessWidget {
  const CompletedTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: const Text(
          'COMPLETED TASKS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 14,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('isCompleted', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 64,
                    color: Colors.white.withOpacity(0.05),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'NO COMPLETED TASKS YET',
                    style: TextStyle(
                      color: Colors.white24,
                      letterSpacing: 1,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          final tasks = snapshot.data!.docs
              .map(
                (doc) => Task.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
          tasks.sort(
            (a, b) => (b.completedAt ?? DateTime.now()).compareTo(
              a.completedAt ?? DateTime.now(),
            ),
          );

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final t = tasks[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.greenAccent,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (t.completedAt != null)
                            Text(
                              'Done: ${DateFormat('dd MMM yyyy, HH:mm').format(t.completedAt!)}',
                              style: const TextStyle(
                                color: Colors.white24,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Column(
                      children: [
                        Icon(
                          Icons.monetization_on,
                          color: Colors.amber,
                          size: 16,
                        ),
                        Text(
                          '+10',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
            },
          );
        },
      ),
    );
  }
}
