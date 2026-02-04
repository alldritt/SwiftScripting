use AppleScript version "2.4" -- Yosemite (10.10) or later
use scripting additions

-- TestScriptableTodos.applescript
-- Comprehensive test of ScriptableTodos scripting facilities.
-- Run with the app already launched.

property passCount : 0
property failCount : 0
property skipCount : 0

on assert(label, actual, expected)
	if actual is equal to expected then
		set my passCount to (my passCount) + 1
		log "  PASS: " & label
	else
		set my failCount to (my failCount) + 1
		log "  FAIL: " & label & " -- expected: " & (expected as text) & "  got: " & (actual as text)
	end if
end assert

on assertContains(label, actual, expected)
	if actual contains expected then
		set my passCount to (my passCount) + 1
		log "  PASS: " & label
	else
		set my failCount to (my failCount) + 1
		log "  FAIL: " & label & " -- expected to contain: " & (expected as text) & "  got: " & (actual as text)
	end if
end assertContains

on skip(label, reason)
	set my skipCount to (my skipCount) + 1
	log "  SKIP: " & label & " -- " & reason
end skip

tell application "ScriptableTodos"
	
	-- =============================================
	log "=== Application Properties ==="
	-- =============================================
	
	my assert("app name", name, "ScriptableTodos")
	
	-- =============================================
	log ""
	log "=== Element Counting (initial state) ==="
	-- =============================================
	
	set listCount to count of todo lists
	my assert("initial todo list count", listCount, 2)
	
	set shoppingItemCount to count of todo items of todo list "Shopping"
	my assert("Shopping item count", shoppingItemCount, 3)
	
	set workItemCount to count of todo items of todo list "Work"
	my assert("Work item count", workItemCount, 2)
	
	-- =============================================
	log ""
	log "=== Get Elements (every) ==="
	-- =============================================
	
	set allLists to every todo list
	my assert("every todo list count", count of allLists, 2)
	
	set allShoppingItems to every todo item of todo list "Shopping"
	my assert("every todo item of Shopping", count of allShoppingItems, 3)
	
	-- =============================================
	log ""
	log "=== Get by Name ==="
	-- =============================================
	
	set shoppingList to todo list "Shopping"
	my assert("todo list by name (Shopping)", name of shoppingList, "Shopping")
	
	set workList to todo list "Work"
	my assert("todo list by name (Work)", name of workList, "Work")
	
	set milkItem to todo item "Milk" of todo list "Shopping"
	my assert("todo item by name (Milk)", name of milkItem, "Milk")
	
	-- =============================================
	log ""
	log "=== Get by Index ==="
	-- =============================================
	
	set firstList to todo list 1
	my assert("todo list 1 name", name of firstList, "Shopping")
	
	set secondList to todo list 2
	my assert("todo list 2 name", name of secondList, "Work")
	
	set firstItem to todo item 1 of todo list "Shopping"
	my assert("todo item 1 of Shopping", name of firstItem, "Milk")
	
	set lastItem to todo item -1 of todo list "Shopping"
	my assert("todo item -1 of Shopping", name of lastItem, "Eggs")

	-- =============================================
	log ""
	log "=== Get by ID ==="
	-- =============================================

	set shoppingID to id of todo list "Shopping"
	set resolvedList to todo list id shoppingID
	my assert("todo list by id round-trip", name of resolvedList, "Shopping")

	set milkID to id of todo item "Milk" of todo list "Shopping"
	set resolvedItem to todo item id milkID of todo list "Shopping"
	my assert("todo item by id round-trip", name of resolvedItem, "Milk")

	-- =============================================
	log ""
	log "=== Get Properties ==="
	-- =============================================
	
	set milkCompleted to completed of todo item "Milk" of todo list "Shopping"
	my assert("Milk completed (initial)", milkCompleted, false)
	
	set milkPriority to priority of todo item "Milk" of todo list "Shopping"
	my assert("Milk priority (initial)", milkPriority, 1)
	
	set milkNotes to notes of todo item "Milk" of todo list "Shopping"
	my assert("Milk notes (initial)", milkNotes, "")
	
	-- Check an item that starts completed
	set writeTestsCompleted to completed of todo item "Write tests" of todo list "Work"
	my assert("Write tests completed (initial)", writeTestsCompleted, true)
	
	-- =============================================
	log ""
	log "=== Set Properties ==="
	-- =============================================
	
	-- Set completed
	set completed of todo item "Milk" of todo list "Shopping" to true
	my assert("set completed to true", completed of todo item "Milk" of todo list "Shopping", true)
	
	-- Set it back
	set completed of todo item "Milk" of todo list "Shopping" to false
	my assert("set completed back to false", completed of todo item "Milk" of todo list "Shopping", false)
	
	-- Set priority
	set priority of todo item "Milk" of todo list "Shopping" to 5
	my assert("set priority to 5", priority of todo item "Milk" of todo list "Shopping", 5)
	
	-- Restore priority
	set priority of todo item "Milk" of todo list "Shopping" to 1
	my assert("restore priority to 1", priority of todo item "Milk" of todo list "Shopping", 1)
	
	-- Set notes
	set notes of todo item "Milk" of todo list "Shopping" to "Whole milk, 2%"
	my assert("set notes", notes of todo item "Milk" of todo list "Shopping", "Whole milk, 2%")
	
	-- Clear notes
	set notes of todo item "Milk" of todo list "Shopping" to ""
	my assert("clear notes", notes of todo item "Milk" of todo list "Shopping", "")
	
	-- Set list name
	set name of todo list "Shopping" to "Groceries"
	my assert("rename list", name of todo list 1, "Groceries")
	
	-- Restore list name
	set name of todo list "Groceries" to "Shopping"
	my assert("restore list name", name of todo list 1, "Shopping")
	
	-- Set item name
	set name of todo item "Milk" of todo list "Shopping" to "Oat Milk"
	my assert("rename item", name of todo item 1 of todo list "Shopping", "Oat Milk")
	
	-- Restore
	set name of todo item "Oat Milk" of todo list "Shopping" to "Milk"
	my assert("restore item name", name of todo item 1 of todo list "Shopping", "Milk")
	
	-- =============================================
	log ""
	log "=== Exists ==="
	-- =============================================
	
	my assert("Shopping list exists", exists todo list "Shopping", true)
	my assert("Work list exists", exists todo list "Work", true)
	my assert("Nonexistent list", exists todo list "Nonexistent", false)
	my assert("Milk item exists", exists todo item "Milk" of todo list "Shopping", true)
	my assert("Nonexistent item", exists todo item "Nonexistent" of todo list "Shopping", false)
	
	-- =============================================
	log ""
	log "=== Make (create) ==="
	-- =============================================
	
	-- Make a new todo list
	set newList to make new todo list
	set newListCount to count of todo lists
	my assert("count after make todo list", newListCount, 3)
	
	-- Make a new todo item in the new list
	set newItem to make new todo item at end of todo list 3
	set newItemCount to count of todo items of todo list 3
	my assert("count after make todo item in new list", newItemCount, 1)
	
	-- Delete the new list (and its item) to clean up
	delete todo list 3
	my assert("count after delete new list", count of todo lists, 2)
	
	-- =============================================
	log ""
	log "=== Make with Properties ==="
	-- =============================================
	
	-- Make a todo list (properties may not be settable via make yet)
	set testList to make new todo list
	set name of todo list 3 to "Test List"
	my assert("new list name after set", name of todo list 3, "Test List")
	
	-- =============================================
	log ""
	log "=== Delete ==="
	-- =============================================
	
	-- Delete by index
	set preDeleteCount to count of todo lists
	delete todo list 3
	set postDeleteCount to count of todo lists
	my assert("delete by index", postDeleteCount, preDeleteCount - 1)
	
	-- Delete by name: add one, then delete it
	make new todo list
	set name of todo list 3 to "Temporary"
	my assert("temp list exists", exists todo list "Temporary", true)
	delete todo list "Temporary"
	my assert("temp list deleted", exists todo list "Temporary", false)
	my assert("count after name delete", count of todo lists, 2)
	
	-- =============================================
	log ""
	log "=== Selection ==="
	-- =============================================
	
	-- Set selection to a list
	set selection to todo list "Shopping"
	set selName to name of selection
	my assert("selection is Shopping", selName, "Shopping")
	
	--	Access todo list items through selection
	set itemNames to name of todo items of selection
	my assert("selection todo item names are", itemNames, ["Milk", "Bread", "Eggs"])
	set notes of todo item "Milk" of selection to "Hello World"
	set itemDesc to notes of todo item "Milk" of selection
	my assert("selection todo item Milk's description is", itemDesc, "Hello World")
	set notes of todo item "Milk" of selection to ""
	
	-- Change selection
	set selection to todo list "Work"
	my assert("selection changed to Work", name of selection, "Work")
	
	-- Change selection to missing value
	set selection to missing value
	my assert("selection changed to Work", selection, missing value)
	
	-- =============================================
	log ""
	log "=== Nested Operations ==="
	-- =============================================
	
	-- Get all item names from a list
	set itemNames to name of every todo item of todo list "Shopping"
	my assert("item names count", count of itemNames, 3)
	my assertContains("item names contains Milk", itemNames, "Milk")
	my assertContains("item names contains Bread", itemNames, "Bread")
	my assertContains("item names contains Eggs", itemNames, "Eggs")
	
	-- Get all priorities
	set priorities to priority of every todo item of todo list "Shopping"
	my assert("priorities count", count of priorities, 3)
	
	-- Get all completed statuses
	set statuses to completed of every todo item of todo list "Shopping"
	my assert("statuses count", count of statuses, 3)
	
	-- =============================================
	log ""
	log "=== Bulk Property Access ==="
	-- =============================================
	
	-- Get properties of a specific item
	set itemRef to todo item "Bread" of todo list "Shopping"
	my assert("Bread name", name of itemRef, "Bread")
	my assert("Bread completed", completed of itemRef, false)
	my assert("Bread priority", priority of itemRef, 2)
	my assert("Bread notes", notes of itemRef, "")
	
	-- =============================================
	log ""
	log "=== List Names ==="
	-- =============================================
	
	set listNames to name of every todo list
	my assert("list names count", count of listNames, 2)
	my assertContains("list names has Shopping", listNames, "Shopping")
	my assertContains("list names has Work", listNames, "Work")
	
end tell

-- =============================================
log ""
log "==========================================="
log "  Results: " & passCount & " passed, " & failCount & " failed, " & skipCount & " skipped"
log "==========================================="

if failCount is 0 then
	return "All " & passCount & " tests passed."
else
	return failCount & " of " & (passCount + failCount) & " tests FAILED."
end if
