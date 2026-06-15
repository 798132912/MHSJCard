extends RefCounted
class_name StatusSystem

func add_status(target: Dictionary, status_name: String, stack: int) -> void:
	var statuses: Array = target.get("statuses", [])
	for status in statuses:
		if status.get("name", "") == status_name:
			status["stack"] += stack
			target["statuses"] = statuses
			return
	statuses.append({"name": status_name, "stack": stack})
	target["statuses"] = statuses

func remove_status(target: Dictionary, status_name: String) -> void:
	var statuses: Array = target.get("statuses", [])
	for i in range(statuses.size() - 1, -1, -1):
		if statuses[i].get("name", "") == status_name:
			statuses.remove_at(i)
	target["statuses"] = statuses

func status_text(unit: Dictionary) -> String:
	var statuses: Array = unit.get("statuses", [])
	if statuses.is_empty():
		return "无"
	var parts: Array[String] = []
	for status in statuses:
		parts.append("%s x%s" % [status.get("name", "状态"), status.get("stack", 1)])
	return "，".join(parts)
