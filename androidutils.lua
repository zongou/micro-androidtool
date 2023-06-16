 VERSION = "1.0.0"

local micro = import("micro")
local config = import("micro/config")
local shell = import("micro/shell")
local util = import("micro/util")
local utf8 = import("unicode/utf8")
local os = import("os")

local isAnotherterm = os.Getenv("TERMSH") ~= ""
local isTermux = os.Getenv("TERMUX_VERSION") ~= ""

function log(msg)
	micro.Log(msg)
end

function info(msg)
	micro.InfoBar():Message(msg)
end

function onStdout(str, arg)
	--micro.Log("ONSTDOUT", str, arg)
end

function onStderr(str, arg)
	micro.Log("ONSTDERR", str, arg)
	--micro.InfoBar():Message(str)
end

function onExit(str, arg)
	--micro.Log("ONEXIT", str, arg)
end

-- Check if exists multiple cursors
function isMuliCursor(bp)
	return bp.Buf:NumCursors() > 1
end

-- Shell command to send buffer as an android intent action 
function __androidSend(buffer)
	local cmd = ""
	
	if isAnotherterm then
		cmd = "{ \"$TERMSH\" send --text-stdin; }"
		-- cmd = "{ stdin=$(cat; printf x); stdin=${stdin%x}; \"$TERMSH\" send --text \"$stdin\"; }"
		-- cmd = "{ stdin=$(sed '$s/$/x/'); stdin=${stdin%x}; \"$TERMSH\" send --text \"$stdin\"; }"
	elseif isTermux then
		-- cmd = "{ stdin=$(cat; printf x); stdin=${stdin%x}; am start -a android.intent.action.SEND -t text/plain -e android.intent.extra.TEXT \"$stdin\"; }"
		cmd = "{ stdin=$(sed '$s/$/x/'); stdin=${stdin%x}; am start -a android.intent.action.SEND -t text/plain -e android.intent.extra.TEXT \"$stdin\"; }"
	end

	local job = shell.JobSpawn("sh", {"-c", cmd}, onStdout, onStderr, onExit, {})
	if (job ~= nil) then
		shell.JobSend(job, buffer)
		job.stdin:Close()
	end
end

-- Shell command to copy buffer to android clipboard
function __androidClipboardCopy(buffer)
	local cmd = ""
	
	if isAnotherterm then
		cmd = "{ \"$TERMSH\" clipboard-copy; }"
		-- cmd = "{ stdin=$(cat; printf x); stdin=${stdin%x}; \"$TERMSH\" send --text \"$stdin\"; }"
		-- cmd = "{ stdin=$(sed '$s/$/x/'); stdin=${stdin%x}; \"$TERMSH\" send --text \"$stdin\"; }"
	elseif isTermux then
		-- clipboard is supported by default on termux when termux-api installed
		local _, err = shell.ExecCommand("sh", "-c", "command -v termux-clipboard-set")
		if err == nil then
			if (config.GetGlobalOption("clipboard") == "internal") then
				cmd = "{ termux-clipboard-set; }" 
			end
		else
			-- cmd = "{ stdin=$(cat; printf x); stdin=${stdin%x}; am start -a android.intent.action.SEND -t text/plain -e android.intent.extra.TEXT \"$stdin\"; }"
			cmd = "{ stdin=$(sed '$s/$/x/'); stdin=${stdin%x}; am start -a android.intent.action.SEND -t text/plain -e android.intent.extra.TEXT \"$stdin\"; }"
		end
	end

	local job = shell.JobSpawn("sh", {"-c", cmd}, onStdout, onStderr, onExit, {})
	if (job ~= nil) then
		shell.JobSend(job, buffer)
		job.stdin:Close()
	end
end

if isAnotherterm then
	-- Copy selection on editor action copy
	function onCopy(bp)
		if isMuliCursor(bp) then return end
		if bp.Cursor:HasSelection() then
			-- bp.Cursor:CopySelection(clipboard.ClipboardReg)
			__androidClipboardCopy(util.String(bp.Cursor:GetSelection()))
			-- bp.freshClip = true
			-- InfoBar.Message("Copied selection")
		end
		-- bp.Relocate()
		return true
	end

	-- Copy Line to android clipboard on editor action copyLine
	function onCopyLine(bp)
		if isMuliCursor(bp) then return end
		if bp.Cursor:HasSelection() then
			return false
		end
		local origLoc = {
			X = bp.Cursor.Loc.X,
			Y = bp.Cursor.Loc.Y
		}
		bp.Cursor:SelectLine()
		-- bp.Cursor:CopySelection(clipboard.ClipboardReg)
		__androidClipboardCopy(util.String(bp.Cursor:GetSelection()))
		-- bp.freshClip = true
		-- InfoBar.Message("Copied line")

		bp.Cursor:Deselect(true)
		bp.Cursor.Loc = origLoc
		-- bp.Relocate()
		return true
	end
end

function androidSendSelection(bp)
	if isMuliCursor(bp) then return end
	if bp.Cursor:HasSelection() then
		__androidSend(util.String(bp.Cursor:GetSelection()))
	else
		local origLoc = {
			X = bp.Cursor.Loc.X,
			Y = bp.Cursor.Loc.Y
		}
		bp.Cursor:SelectLine()
		__androidSend(util.String(bp.Cursor:GetSelection()))
		bp.Cursor:Deselect(true)
		bp.Cursor.Loc = origLoc
	end
end

function init()
	-- For anotherterm and termux on android
	if (isAnotherterm or isTermux) then
		config.MakeCommand("sendselection", androidSendSelection, config.NoComplete)
		config.AddRuntimeFile("androidutils", config.RTHelp, "help/androidutils.md")
		-- config.TryBindKey("F9", "lua:androidutils.androidSendSelction", false)
	end
end