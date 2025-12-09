// lib/screens/cce/cce_task_list_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CceTaskListScreen extends StatelessWidget {
  const CceTaskListScreen({super.key});

  final List<Map<String, dynamic>> _tasks = const [
    {
      'id': 'CCE-2024-001',
      'surveyNo': 'Khasra 124/A',
      'farmer': 'Ramesh Kumar',
      'village': 'Rampur',
      'crop': 'Wheat - HD2967',
      'status': 'SCHEDULED',
      'dueDate': 'Due: Tomorrow'
    },
    {
      'id': 'CCE-2024-002',
      'surveyNo': 'Khasra 89/B',
      'farmer': 'Suresh Singh',
      'village': 'Lakhanpur',
      'crop': 'Wheat - PBW 343',
      'status': 'ONGOING',
      'dueDate': 'Due: Today'
    },
    {
      'id': 'CCE-2024-003',
      'surveyNo': 'Khasra 212',
      'farmer': 'Anita Devi',
      'village': 'Rampur',
      'crop': 'Mustard',
      'status': 'COMPLETED',
      'dueDate': 'Completed'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Assigned CCE Tasks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          final isCompleted = task['status'] == 'COMPLETED';
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: isCompleted 
                ? null 
                : () => context.push('/cce-form', extra: {'taskId': task['id']}),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          task['id'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 12
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(task['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getStatusColor(task['status'])),
                          ),
                          child: Text(
                            task['status'],
                            style: TextStyle(
                              color: _getStatusColor(task['status']),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      task['surveyNo'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("Farmer: ${task['farmer']} • ${task['village']}"),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.grass, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(task['crop'], style: const TextStyle(fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(task['dueDate'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SCHEDULED': return Colors.blue;
      case 'ONGOING': return Colors.orange;
      case 'COMPLETED': return Colors.green;
      default: return Colors.grey;
    }
  }
}