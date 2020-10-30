extends Control

signal files_found
signal got_file_sizes
signal copied

var milestone = 50

var mutex = Mutex.new()
var threads = []

var xMin = 1920
var yMin = 1080

var fileSizeMin = 100
var fileSizeMult = 1000
var fileSizeDesignation = "kb"

var srcDir = "C:/"
var toDir = "C:/"

var toComputeRes = true
var toComputeSize = true
var toComputePortraitMode = false

var resBiggerThenEnabled = false
var sizeBiggerThenEnabled = false

enum operatingModes {Either, Both, TPC} #Total Pixel Count
var operatingModeID = 0

var displayFoldersFound = true
var displayFilesFound = false
var displayMilestones = true
var displayTextLine = 0
var maxTextEditLines = 1000
var textEditHiddenLines = 0

var files = []
var filesAndSizes = []

var working_layers = 0

var steps = 3

func _on_SetSrcDirButton_pressed():
	$SrcFileDialog.popup()

func _on_ToDirButton_pressed():
	$ToFileDialog.popup()

func _on_SrcFileDialog_dir_selected(dir):
	$VBoxMain/VBoxSub/DirContainer/SrcDirLineEdit.text = dir
	srcDir = dir

func _on_ToFileDialog_dir_selected(dir):
	$VBoxMain/VBoxSub/DirContainer/ToDirLineEdit.text = dir
	toDir = dir

func _on_XSpinBox_value_changed(value):
	xMin = value

func _on_YSpinBox_value_changed(value):
	yMin = value

func _on_ResCheckBox_toggled(button_pressed):
	toComputeRes = button_pressed
	$VBoxMain/VBoxSub/VarContainer/XHBoxContainer/XSpinBox.editable = button_pressed
	$VBoxMain/VBoxSub/VarContainer/YHBoxContainer/YSpinBox.editable = button_pressed
	$VBoxMain/VBoxSub/VarContainer/XHBoxContainer/OMOptionButton.disabled = !button_pressed
	$VBoxMain/VBoxSub/HBoxContainer/PMCheckBox.disabled = !button_pressed

func _on_SizeOptionButton_item_selected(id):
	match(id):
		0:
			fileSizeMult = 0
		1:
			fileSizeMult = 1000
		2:
			fileSizeMult = 1000000
		3:
			fileSizeMult = 1000000000
	
	fileSizeDesignation = $VBoxMain/VBoxSub/VarContainer/SizeOptionButton.text

func _on_SizeCheckBox_toggled(button_pressed):
	toComputeSize = button_pressed
	$VBoxMain/VBoxSub/VarContainer/SizeSpinBox.editable = button_pressed
	$VBoxMain/VBoxSub/VarContainer/SizeOptionButton.disabled = !button_pressed

func _on_SizeSpinBox_value_changed(value):
	fileSizeMin = value

func display_text(text = String()):
	$VBoxMain/TextEdit.text = str($VBoxMain/TextEdit.text, text, "\n")
	$VBoxMain/TextEdit.cursor_set_line($VBoxMain/TextEdit.get_line_count())
	
	if $VBoxMain/TextEdit.get_line_count() > maxTextEditLines:
		maxTextEditLines += 1
		$VBoxMain/TextEdit.set_line_as_hidden(textEditHiddenLines, true)
		textEditHiddenLines += 1

func dir_contents(path, layer = int()):
	var dir = Directory.new()
	mutex.lock()
	working_layers += 1
	mutex.unlock()
	
	if dir.open(path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			yield(get_tree().create_timer(0.0000000000000001), "timeout")
			if dir.current_is_dir():
				if file_name == "." or file_name == "..":
					pass
				else: 
					if displayFoldersFound:
						display_text("Found directory: " + file_name)
					dir_contents(str(path + "/" + file_name), layer + 1)
			else:
				mutex.lock()
				if displayFilesFound:
					display_text("Found file: " + str(path + "/" + file_name))
				if file_name.ends_with(".jpg") or file_name.ends_with(".png") or file_name.ends_with(".jpeg"):
					files.append({"path": str(path + "/" + file_name), "file_name": file_name})
				if displayMilestones and (files.size() % milestone == 0):
					display_text(str("Found ", files.size(), " images so far!"))
				mutex.unlock()
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	
	
	mutex.lock()
	working_layers -= 1
	mutex.unlock()
	
	if working_layers == 0:
		emit_signal("files_found")
	return

func _on_GoButton_pressed():
	var error_state = false
	
	if srcDir == "C:/":
		display_text("Source Directory is not set!")
		error_state = true
	
	if toDir == "C:/":
		display_text("To Directory is not set!")
		error_state = true
	
	if toDir == srcDir:
		display_text("The source directory is the same as the to directory!")
		error_state = true
	
	if !toComputeRes and !toComputeSize:
		display_text("You are not computing either the resolution or size of files found!")
		error_state = true
	
	if error_state:
		return
	
	$VBoxMain/HBoxContainer/GoButton.disabled = true
	$VBoxMain/VBoxSub/VarContainer/SizeCheckBox.disabled = true
	$VBoxMain/VBoxSub/VarContainer/SizeOptionButton.disabled = true
	$VBoxMain/VBoxSub/VarContainer/SizeSpinBox.editable = false
	$VBoxMain/VBoxSub/VarContainer/ResCheckBox.disabled = true
	$VBoxMain/VBoxSub/VarContainer/XHBoxContainer/XSpinBox.editable = false
	$VBoxMain/VBoxSub/VarContainer/YHBoxContainer/YSpinBox.editable = false
	$VBoxMain/VBoxSub/DirContainer/SetSrcDirButton.disabled = true
	$VBoxMain/VBoxSub/DirContainer/ToDirButton.disabled = true
	$VBoxMain/HBoxContainer/MoreOptionsButton.disabled = true
	$VBoxMain/VBoxSub/HBoxContainer/SmallerBiggerOptionButton.disabled = true
	$VBoxMain/VBoxSub/HBoxContainer/PMCheckBox.disabled = true
	$VBoxMain/VBoxSub/VarContainer/XHBoxContainer/OMOptionButton.disabled = true
	
	if threads.size() == 0: threads.append(Thread.new())
	threads[0].start(self, "dir_contents", srcDir)
	
	yield(self,"files_found")
	
	for thread in threads:
		thread.wait_to_finish()
	
	$VBoxMain/TotalProgressBar.value = 100 / steps
	display_text("-----------")
	display_text("Found Files")
	display_text("-----------")
	
	threads[0].start(self, "get_file_sizes", 0)
	
	yield(self, "got_file_sizes")
	
	for thread in threads:
		thread.wait_to_finish()
	
	display_text("----------------------------------------------------------")
	display_text(str("Copying ", filesAndSizes.size(), " out of ", files.size(),"!"))
	display_text("----------------------------------------------------------")
	
	threads[0].start(self, "copy_files", 0)
	yield(self, "copied")
	
	
	for thread in threads:
		thread.wait_to_finish()
	
	$VBoxMain/HBoxContainer/GoButton.disabled = false
	$VBoxMain/VBoxSub/VarContainer/SizeCheckBox.disabled = false
	$VBoxMain/VBoxSub/VarContainer/ResCheckBox.disabled = false
	$VBoxMain/VBoxSub/DirContainer/SetSrcDirButton.disabled = false
	$VBoxMain/VBoxSub/DirContainer/ToDirButton.disabled = false
	$VBoxMain/HBoxContainer/MoreOptionsButton.disabled = false
	$VBoxMain/VBoxSub/HBoxContainer/SmallerBiggerOptionButton.disabled = false
	
	$VBoxMain/VBoxSub/VarContainer/XHBoxContainer/XSpinBox.editable = $VBoxMain/VBoxSub/VarContainer/ResCheckBox.pressed
	$VBoxMain/VBoxSub/VarContainer/YHBoxContainer/YSpinBox.editable = $VBoxMain/VBoxSub/VarContainer/ResCheckBox.pressed
	$VBoxMain/VBoxSub/VarContainer/XHBoxContainer/OMOptionButton.disabled = !$VBoxMain/VBoxSub/VarContainer/ResCheckBox.pressed
	$VBoxMain/VBoxSub/HBoxContainer/PMCheckBox.disabled = !$VBoxMain/VBoxSub/VarContainer/ResCheckBox.pressed
	
	if operatingModeID == operatingModes.TPC:
		$VBoxMain/VBoxSub/HBoxContainer/PMCheckBox.disabled = true
	
	$VBoxMain/VBoxSub/VarContainer/SizeSpinBox.editable = $VBoxMain/VBoxSub/VarContainer/SizeCheckBox.pressed
	$VBoxMain/VBoxSub/VarContainer/SizeOptionButton.disabled = !$VBoxMain/VBoxSub/VarContainer/SizeCheckBox.pressed
	
	display_text("-----")
	display_text("DONE")
	display_text("-----")
	
	files.clear()
	filesAndSizes.clear()

func _on_DisplayFilesCheckBox_toggled(button_pressed):
	displayFilesFound = button_pressed

func _on_DisplayFoldersCheckBox_toggled(button_pressed):
	displayFoldersFound = button_pressed

func _on_DisplayMilestonesCheckBox_toggled(button_pressed):
	displayMilestones = button_pressed

#Checks if a file is to be copied or not and gets the files sizes (resolution and file size)
func get_file_sizes(_a = null):
	var i = float()
	$VBoxMain/CurrentProgressBar.value = 0
	var totalProgressStartValue = $VBoxMain/TotalProgressBar.value
	
	
	for file in files:
		var path = file.path
		yield(get_tree().create_timer(0.0000000000000001), "timeout")
		i += 1
		var completion = float(i / files.size()) * 100
		$VBoxMain/CurrentProgressBar.value = completion
		$VBoxMain/TotalProgressBar.value = totalProgressStartValue + (completion / steps)
		
		var file_size = get_file_size(path)
		var to_copy = false
		
		if toComputeSize:
			if sizeBiggerThenEnabled:
				to_copy = file_size > (fileSizeMin*fileSizeMult)
			else:
				to_copy = file_size < (fileSizeMin*fileSizeMult)
		
		if toComputeRes:
			if !to_copy:
				var temp_image = Image.new()
				temp_image.load(path)
				
				if resBiggerThenEnabled:
					match(operatingModeID):
						operatingModes.Either:
							if temp_image.data.height > yMin or temp_image.data.width > xMin:
								to_copy = true
								
						operatingModes.Both:
							if temp_image.data.height > yMin and temp_image.data.width > xMin:
								to_copy = true
								
						operatingModes.TPC:
							if temp_image.data.height * temp_image.data.width > yMin * xMin:
								to_copy = true
				
				else:
					match(operatingModeID):
						operatingModes.Either:
							if temp_image.data.height < yMin or temp_image.data.width < xMin:
								to_copy = true
								
						operatingModes.Both:
							if temp_image.data.height < yMin and temp_image.data.width < xMin:
								to_copy = true
								
						operatingModes.TPC:
							if temp_image.data.height * temp_image.data.width < yMin * xMin:
								to_copy = true
			
			
			if !to_copy:
				if toComputePortraitMode:
					var temp_image = Image.new()
					temp_image.load(path)
				
					if resBiggerThenEnabled:
						match(operatingModeID):
							operatingModes.Either:
								if temp_image.data.height > xMin or temp_image.data.width > yMin:
									to_copy = true
								
							operatingModes.Both:
								if temp_image.data.height > xMin and temp_image.data.width > yMin:
									to_copy = true
									
#							operatingModes.TPC: --> Dead code
#								if temp_image.data.height * temp_image.data.width > yMin * xMin:
#									to_copy = true
					
					else:
						match(operatingModeID):
							operatingModes.Either:
								if temp_image.data.height < xMin or temp_image.data.width < yMin:
									to_copy = true
									
							operatingModes.Both:
								if temp_image.data.height < xMin and temp_image.data.width < yMin:
									to_copy = true
									
#							operatingModes.TPC: --> Dead Code
#								if temp_image.data.height * temp_image.data.width < yMin * xMin:
#									to_copy = true
			
		
		if to_copy:
			filesAndSizes.append({"path": path, "size": file_size, "file_name": file.file_name})
		
			if displayFilesFound:
				file_size = str(round(float(file_size) / fileSizeMult * 100) / 100)
			
				if file_size.length() > 6:
					file_size = str(file_size)
					file_size = str(file_size.left(file_size.length() - 6), ",", file_size.right(file_size.length() - 6))
				
				display_text(str(path, " is ", file_size, " ", fileSizeDesignation, "."))
	
	emit_signal("got_file_sizes")

func copy_files(_a):
	var i = float()
	var totalProgressStartValue = $VBoxMain/TotalProgressBar.value
	
	for file in filesAndSizes:
		yield(get_tree().create_timer(0.0000000000000001), "timeout")
		i += 1
		var completion = float(i / filesAndSizes.size()) * 100
		$VBoxMain/CurrentProgressBar.value = completion
		$VBoxMain/TotalProgressBar.value = totalProgressStartValue + (completion / steps)
		copy_file(file.path, str(toDir, "/", file.file_name))
	
	$VBoxMain/CurrentProgressBar.value = 100
	$VBoxMain/TotalProgressBar.value = 100
	emit_signal("copied")

func get_file_size(path):
	var file = File.new()
	file.open(path, File.READ)
	var size = file.get_len()
	file.close()
	return size

func copy_file(src, to):
	var dir = Directory.new()
	dir.copy(src, to)

func _on_MoreOptionsButton_pressed():
	$AODialog.popup()

func _on_SmallerBiggerOptionButton_item_selected(id):
	_on_FSmallerBiggerOptionButton_item_selected(id)
	match(id):
		0: #Smaller then (default)
			resBiggerThenEnabled = false
		1: #Bigger then
			resBiggerThenEnabled = true

func _on_PMCheckBox_toggled(button_pressed):
	toComputePortraitMode = button_pressed

func _on_OMOptionButton_item_selected(id):
	match(id):
		0: #Either Side (default)
			operatingModeID = operatingModes.Both
		1: #Both Sides
			operatingModeID = operatingModes.Either
		2: #Total Pixel Count
			operatingModeID = operatingModes.TPC
			$VBoxMain/VBoxSub/HBoxContainer/PMCheckBox.disabled = true

func _on_FSmallerBiggerOptionButton_item_selected(id):
	match(id):
		0: #Smaller then (default)
			sizeBiggerThenEnabled = false
		1: #Bigger then
			sizeBiggerThenEnabled = true
