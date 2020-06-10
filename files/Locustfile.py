from locust import HttpUser, TaskSet, task, between

class UserTasks(TaskSet):
    @task
    def index(self):
        self.client.get("/")
    
class WebsiteUser(HttpUser):
    wait_time = between(2, 5)
    tasks = [UserTasks]
