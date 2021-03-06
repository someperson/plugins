-- SPDX-License-Identifier: MIT
hexchat.register('Buffextras', '1', "Format messages from ZNC's buffextras module")

hexchat.hook_server_attrs('PRIVMSG', function (word, word_eol, attrs)
	if not word[1]:match('^:%*buffextras!') then
		return
	end

	local channel = word[3]
	local nick, host = word[4]:match('^:([^!]+)!(.*)$')

	local function is_event (event)
		return word_eol[5]:sub(1, #event) == event
	end

	local function emit (event, ...)
		hexchat.emit_print_attrs(attrs, event, ...)
	end

	if is_event('joined') then
		emit('Join', nick, channel, host)
	elseif is_event('quit') then
		emit('Quit', nick, word_eol[6], host)
	elseif is_event('parted') then
		local reason = word_eol[6]
		if reason and reason ~= '' then
			emit('Part with Reason', nick, host, channel, reason)
		else
			emit('Part', nick, host, channel)
		end
	elseif is_event('is now known as') then
		emit('Change Nick', nick, word[9])
	elseif is_event('changed the topic to') then
		emit('Topic Change', nick, word_eol[9], channel)
	elseif is_event('kicked') then
		emit('Kick', nick, word[6], channel, word_eol[9])
	elseif is_event('set mode') then
		modes = word_eol[7]:match('^(.*%S)')
		name = nick
		if name == nil then
			name = word[4]:match('^:([^!]+)$')
		end
		if hexchat.prefs['irc_raw_modes'] == true then
			emit('Raw Modes', name, string.format('%s %s', channel, modes))
		else
			local nickmodes = hexchat.props['nickmodes']
			local chanmodes = hexchat.props['chanmodes']

			server = hexchat.get_info('server')
			local chanmodes = chanmodes[server]
			if chanmodes == nil then
				chanmodes = 'beI,k,l'
			end

			modes_for_lists, modes_with_param, modes_with_param_when_set, modes_without_param = chanmodes:match('^([^,]*),?([^,]*),?([^,]*),?([^,]*)$')

			local sign
			local param_pos = 8
			local flags = word[7]
			for i = 1, #flags do
				flag = flags:sub(i,i)
				if flag == '+' then
					sign = '+'
				elseif flag == '-' then
					sign = '-'
				elseif flag == 'k' then
					if sign == '+' then
						param = word[param_pos]
						param_pos = param_pos + 1
						emit('Channel Set Key', name, param)
					else
						emit('Channel Remove Keyword', name)
					end
				elseif flag == 'l' then
					if sign == '+' then
						param = word[param_pos]
						param_pos = param_pos + 1
						emit('Channel Set Limit', name, param)
					else
						emit('Channel Remove Limit', name)
					end
				elseif flag == 'o' then
					param = word[param_pos]
					param_pos = param_pos + 1
					if sign == '+' then
						emit('Channel Operator', name, param)
					else
						emit('Channel DeOp', name, param)
					end
				elseif flag == 'h' then
					param = word[param_pos]
					param_pos = param_pos + 1
					if sign == '+' then
						emit('Channel Half-Operator', name, param)
					else
						emit('Channel DeHalfOp', name, param)
					end
				elseif flag == 'v' then
					param = word[param_pos]
					param_pos = param_pos + 1
					if sign == '+' then
						emit('Channel Voice', name, param)
					else
						emit('Channel DeVoice', name, param)
					end
				elseif flag == 'b' then
					param = word[param_pos]
					param_pos = param_pos + 1
					if sign == '+' then
						emit('Channel Ban', name, param)
					else
						emit('Channel UnBan', name, param)
					end
				elseif flag == 'e' then
					param = word[param_pos]
					param_pos = param_pos + 1
					if sign == '+' then
						emit('Channel Exempt', name, param)
					else
						emit('Channel Remove Exempt', name, param)
					end
				elseif flag == 'I' then
					param = word[param_pos]
					param_pos = param_pos + 1
					if sign == '+' then
						emit('Channel INVITE', name, param)
					else
						emit('Channel Remove Invite', name, param)
					end
				elseif flag == 'q' and string.find(modes_for_lists, 'q') then
					param = word[param_pos]
					param_pos = param_pos + 1
					if sign == '+' then
						emit('Channel Quiet', name, param)
					else
						emit('Channel UnQuiet', name, param)
					end
				elseif string.find(nickmodes, flag) or string.find(modes_for_lists, flag) or string.find(modes_with_param, flag) then
					param = word[param_pos]
					param_pos = param_pos + 1
					emit('Channel Mode Generic', name, sign, flag, string.format('%s %s', channel, param))
				elseif string.find(modes_with_param_when_set, flag) then
					if sign == '+' then
						param = word[param_pos]
						param_pos = param_pos + 1
						emit('Channel Mode Generic', name, sign, flag, string.format('%s %s', channel, param))
					else
						emit('Channel Mode Generic', name, sign, flag, channel)
					end
				else
					emit('Channel Mode Generic', name, sign, flag, channel)
				end
			end
		end
	else
		return -- Unknown event
	end

	return hexchat.EAT_ALL
end, hexchat.PRI_HIGH)
