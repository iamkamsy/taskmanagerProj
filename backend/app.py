from flask import Flask, request, jsonify 
from flask_cors import CORS 
from db import db 
from bson import ObjectId 

app = Flask(__name__)  
CORS(app)  
task_collection = db["tasks"]  

@app.route("/tasks", methods=["GET"]) 
def get_tasks():
    tasks = []
    for t in task_collection.find({}, sort=[("deadline", 1)]):
        tasks.append({
            "_id": str(t["_id"]),  
            "name": t["name"],
            "completed": t.get("completed", False),
            "deadline": t.get("deadline", "")
        })
    return jsonify({"tasks": tasks})  

#creates new tasks
@app.route("/tasks", methods=["POST"]) 
def create_task():
    data = request.json
    new_task = {
        "name": data["name"],
        "completed": False, #defaults to not completed
        "deadline": data["deadline"]
    }

    result = task_collection.insert_one(new_task)  
    new_task["_id"] = str(result.inserted_id)

    return jsonify({"task": new_task}) 

#deletes tasks
@app.route("/tasks/<string:task_id>", methods=["DELETE"]) 
def delete_task(task_id):
    result = task_collection.delete_one({"_id": ObjectId(task_id)})
    if result.deleted_count == 1:
        return jsonify({"message": "Task deleted"}), 200
    else:
        return jsonify({"error": "task not found"}), 404

#sets tasks as completed
@app.route("/tasks/<string:task_id>/toggle", methods=["PATCH"])
def toggle_task(task_id):
    task = task_collection.find_one({"_id": ObjectId(task_id)})
    if not task:
        return jsonify({"error": "Task not found"}), 404

    new_status = not task.get("completed", False)
    task_collection.update_one({"_id": ObjectId(task_id)}, {"$set": {"completed": new_status}})
    return jsonify({"message": "Task updated", "completed": new_status})

#edits tasks
@app.route("/tasks/<string:task_id>", methods=["PATCH"])
def update_task(task_id):
    data = request.json
    updates = {} 

    if "name" in data:
        updates["name"] = data["name"]
    if "deadline" in data:
        updates["deadline"] = data["deadline"]
    
    if not updates:
        return jsonify({"error": "No valid fields to update"}), 400


    result = task_collection.update_one(
        {"_id": ObjectId(task_id)},
        {"$set": updates}
    )

    if result.matched_count == 0:
        return jsonify({"error": "Task not found"}), 404

    return jsonify({"message": "Task updated", "updates": updates})

@app.route("/")  
def health_check():
    return jsonify({"status": "OK", "message": "TaskManager API is live"})  

if __name__ == '__main__':
    app.run(port = 5000, debug=True)  