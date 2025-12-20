import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<String>> _events = {
    DateTime.utc(2024, 5, 20): ['Họp nhóm', 'Làm bài tập lớn'],
    DateTime.utc(2024, 5, 22): ['Kiểm tra giữa kỳ'],
  };
  
  // Set để lưu các ngày đã được đánh dấu
  final Set<DateTime> _markedDays = {};

  // Hàm xóa sự kiện trong lịch
  void _deleteEvent(DateTime day, int index) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    setState(() {
      if (_events.containsKey(normalizedDay)) {
        _events[normalizedDay]!.removeAt(index);
        if (_events[normalizedDay]!.isEmpty) {
          _events.remove(normalizedDay);
        }
      }
    });
  }

  // Dialog xác nhận xóa sự kiện trong lịch
  void _showDeleteEventDialog(BuildContext context, DateTime day, int index, String eventTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa sự kiện "$eventTitle"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteEvent(day, index);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  // Dialog hiển thị chi tiết sự kiện trong lịch
  void _showEventDetailsDialog(BuildContext context, DateTime day, String eventTitle) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    final formattedDate = '${day.day}/${day.month}/${day.year}';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.event, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  eventTitle,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Ngày:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  List<String> _getEventsForDay(DateTime day) {
    // Normalize the day to UTC to match the keys in the _events map.
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  // Kiểm tra ngày có được đánh dấu không
  bool _isMarked(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _markedDays.contains(normalizedDay);
  }

  // Đánh dấu/bỏ đánh dấu ngày
  void _toggleMarkDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    setState(() {
      if (_markedDays.contains(normalizedDay)) {
        _markedDays.remove(normalizedDay);
      } else {
        _markedDays.add(normalizedDay);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.week: 'Week',
            },
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getEventsForDay,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
            ),
            calendarBuilders: CalendarBuilders(
              // Hiển thị marker cho ngày được đánh dấu
              markerBuilder: (context, date, events) {
                if (_isMarked(date)) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                return null;
              },
              // Tùy chỉnh màu nền cho ngày được đánh dấu (không phải ngày được chọn)
              defaultBuilder: (context, date, focused) {
                if (_isMarked(date) && !isSameDay(_selectedDay, date)) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.orange,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
              // Tùy chỉnh cho ngày được chọn và đánh dấu
              selectedBuilder: (context, date, focused) {
                if (_isMarked(date)) {
                  return Container(
                    margin: const EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: selectedEvents.isEmpty
                ? const Center(
                    child: Text('Không có sự kiện nào trong ngày này.'),
                  )
                : ListView.builder(
                    itemCount: selectedEvents.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                        child: ListTile(
                          title: Text(selectedEvents[index]),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.info_outline, color: Colors.blue),
                                onPressed: () => _showEventDetailsDialog(
                                  context,
                                  _selectedDay ?? _focusedDay,
                                  selectedEvents[index],
                                ),
                                tooltip: 'Xem chi tiết',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteEventDialog(
                                  context,
                                  _selectedDay ?? _focusedDay,
                                  index,
                                  selectedEvents[index],
                                ),
                                tooltip: 'Xóa sự kiện',
                              ),
                            ],
                          ),
                          onTap: () => _showEventDetailsDialog(
                            context,
                            _selectedDay ?? _focusedDay,
                            selectedEvents[index],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedDay != null
          ? FloatingActionButton(
              onPressed: () {
                _toggleMarkDay(_selectedDay!);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isMarked(_selectedDay!)
                          ? 'Đã đánh dấu ngày ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}'
                          : 'Đã bỏ đánh dấu ngày ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              tooltip: _isMarked(_selectedDay!)
                  ? 'Bỏ đánh dấu ngày'
                  : 'Đánh dấu ngày',
              child: Icon(
                _isMarked(_selectedDay!)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
            )
          : null,
    );
  }
}
