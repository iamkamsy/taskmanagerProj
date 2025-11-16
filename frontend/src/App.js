import React, { useState, useEffect } from "react";
import axios from "axios";
import "./App.css"

function App() {
  const [tasks, setTasks] = useState([]);
  const [newTask, setNewTask] = useState("");
  const [editingTaskId, setEditingTaskId] = useState(null);
  const [editedTaskName, setEditedTaskName] = useState("");
  const [newDeadline, setNewDeadline] = useState("");
  const [editedDeadline, setEditedDeadline] = useState("");

  // Load tasks when the page loads
  useEffect(() => {
    axios.get("http://127.0.0.1:5000/tasks")
      .then(response => {
        const sorted = response.data.tasks.sort((a, b) => new Date(a.deadline) - new Date(b.deadline));
        setTasks(sorted);
      })
      .catch(error => {
        console.error("Error fetching tasks:", error);
      });
  }, []);

  // Add a new task
  const addTask = () => {
    if (!newTask.trim() || !newDeadline) return;

    axios.post("http://127.0.0.1:5000/tasks", {
      name: newTask,
      deadline: newDeadline,
    })
    .then(response => {
      const updatedTasks = [...tasks, response.data.task];
      updatedTasks.sort((a, b) => new Date(a.deadline) - new Date(b.deadline));
      setTasks(updatedTasks);
      setNewTask("");
      setNewDeadline("");
    })
    .catch(error => {
      console.error("Error adding task:", error);
    });
  };
  
  // deletes tasks
  const deleteTask = (id) => {
    axios.delete(`http://127.0.0.1:5000/tasks/${id}`)
      .then(() => {
        setTasks(tasks.filter(task => task._id !== id));
      })
      .catch(error => {
        console.error("Error deleting task:", error);
      }
    );
  };

  // marks tasks completed
  const toggleTask = (id) => {
  axios.patch(`http://127.0.0.1:5000/tasks/${id}/toggle`)
    .then(response => {
      setTasks(tasks.map(task =>
        task._id === id ? { ...task, completed: response.data.completed } : task
      ));
    })
    .catch(error => {
      console.error("Error toggling task:", error);
    });
  };

  // whenever you start editing the task
  const startEditing = (task) => {
    setEditingTaskId(task._id);
    setEditedTaskName(task.name);
    setEditedDeadline(task.deadline);
  };

  const saveEdit = () => {
    axios.patch(`http://127.0.0.1:5000/tasks/${editingTaskId}`, {
      name: editedTaskName,
      deadline: editedDeadline, 
    })
    .then(response => {
      const updatedTasks = tasks.map(task =>
        task._id === editingTaskId
          ? { ...task, ...response.data.updates }
          : task
      );
      updatedTasks.sort((a, b) => new Date(a.deadline) - new Date(b.deadline));
      setTasks(updatedTasks);
      setEditingTaskId(null);
      setEditedTaskName("");
      setEditedDeadline("");
    })
    .catch(error => {
      console.error("Error updating task:", error);
    });
  };

  return (
    <div className="app-container">
      <h1 className="header">Task Manager</h1>

      <div className="task-entry">
        <input
          type="text"
          placeholder="Enter a task..."
          value={newTask}
          onChange={(e) => setNewTask(e.target.value)}
          className="input-text"
        />
        <input
          type="date"
          value={newDeadline}
          onChange={(e) => setNewDeadline(e.target.value)}
          className="input-date"
        />

        <button 
          onClick={addTask}
          className="button-primary"
        >
          Add Task
        </button>
      </div>

      <ul className="task-list">
        {tasks.map(task => (
          <li key={task._id} className="task-card">
            {editingTaskId === task._id ? (
              <div className="task-editing">
                <input
                  type="text"
                  value={editedTaskName}
                  onChange={(e) => setEditedTaskName(e.target.value)}
                  className="input-text"
                />
                <input
                  type="date"
                  value={editedDeadline}
                  onChange={(e) => setEditedDeadline(e.target.value)}
                  className="input-date"
                />
                <button onClick={saveEdit} className="button-primary">Save</button>
                <button onClick={() => setEditingTaskId(null)} className="button-muted">Cancel</button>
              </div>
            ) : (
              <>
                <div className="task-display">
                  <span
                    onClick={() => toggleTask(task._id)}
                    className={`task-name ${task.completed ? "completed" : ""}`}
                  >
                    {task.name}
                  </span>
                  <span className="task-deadline">
                    (Complete By: {new Date(task.deadline).toLocaleDateString("en-US")})
                  </span>
                </div>
                <div className="task-actions">
                  <button onClick={() => startEditing(task)} className="button-secondary">Edit</button>
                  <button onClick={() => deleteTask(task._id)} className="button-danger">Delete</button>
                </div>
                
              </>
            )}
          </li>
        ))}
      </ul>

    </div>
  );
}

export default App;
