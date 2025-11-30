import 'package:awesome_task_manager/awesome_task_manager.dart';

class TaskService {
  final SharedResultManager sharedTaskManager;

  TaskService({SharedResultManager? mockedSharedManager})
    : sharedTaskManager =
          mockedSharedManager ??
          AwesomeTaskManager().createSharedResultManager(
            managerId: 'sharedTasks',
          );

  Future<TaskResult<R>> createTask<R>(
    String tag,
    String taskId,
    Task<R> task,
  ) async {
    return sharedTaskManager.executeTaskSharingResult<R>(
      callerReference: tag,
      taskId: taskId,
      task: task,
    );
  }
}
