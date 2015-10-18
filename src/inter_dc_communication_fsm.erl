%% -------------------------------------------------------------------
%%
%% Copyright (c) 2014 SyncFree Consortium.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(inter_dc_communication_fsm).
-behaviour(gen_fsm).

%% This module handles incoming socket connections requests from other DC.
%% Currently handles only "replicate update" requests.
%% Other request messages must be added if required


-record(state, {socket, last_pid, child_pid, prev_child_pid}). % the current socket

-export([start_link/2]).
-export([init/1,
         code_change/4,
         handle_event/3,
         handle_info/3,
         handle_sync_event/4,
         terminate/3]).
-export([receive_message/2,
	 bad_msg/2
         %% close_socket/2
        ]).

-define(TIMEOUT,10000).

%% ===================================================================
%% Public API
%% ===================================================================

start_link(Socket, LastPid) ->
    gen_fsm:start_link(?MODULE, [Socket, LastPid], []).

%% ===================================================================
%% gen_fsm callbacks
%% ===================================================================


init([Socket, LastPid]) ->
    {A1,A2,A3} = os:timestamp(),
    random:seed(A1, A2, A3),
    {ok, receive_message, #state{socket=Socket, last_pid=LastPid},0}.


receive_message(timeout, State=#state{socket=Socket,last_pid=_LastPid}) ->
    %% MyPid = self(),
    case gen_tcp:recv(Socket, 0) of
        {ok, Message} ->
            case binary_to_term(Message) of
                {replicate, _SenderDc, Updates} ->
                    %%ok =  inter_dc_recvr_vnode:store_updates(Updates),
		    %% TODO: this is not safe because you can recieve a safe time beofre
		    %% you have finished processing previous received update
		    ok = gen_tcp:send(Socket, term_to_binary(acknowledge)),
		    %%gen_tcp:close(Socket),
		    %% case LastPid of
		    %% 	none ->
		    %% 	    ok;
		    %% 	_ ->
		    %% 	    LastPid ! {MyPid, check_prev_done_process},
		    %% 	    receive
		    %% 		{MyPid, prev_done_process} ->
		    %% 		    ok
		    %% 	    end
		    %% end,
		    ok = inter_dc_recvr_vnode:store_updates(Updates),
		    %% receive
		    %% 	{NewPid, check_prev_done_process} ->
		    %% 	    NewPid ! {NewPid, prev_done_process}
		    %% end,
		    {next_state, receive_message, State, 0};
		Unknown ->
                    lager:error("Weird message received in inter_dc_comm_fsm ~p end", [Unknown]),
		    %% gen_tcp:close(Socket),
		    %% case LastPid of
		    %% 	none ->
		    %% 	    ok;
		    %% 	_ ->
		    %% 	    LastPid ! {MyPid, check_prev_done_process},
		    %% 	    receive
		    %% 		{MyPid, prev_done_process} ->
		    %% 		    ok
		    %% 	    end
		    %% end,
		    %% receive
		    %% 	{NewPid, check_prev_done_process} ->
		    %% 	    NewPid ! {NewPid, prev_done_process}
		    %% end,
		    {next_state, bad_msg, State, 0}		    
	    end;
	{error, Reason} ->
            lager:error("Problem with the socket, reason: ~p", [Reason]),
	    gen_tcp:close(Socket),
	    %% case LastPid of
	    %% 	none ->
	    %% 	    ok;
	    %% 	_ ->
	    %% 	    LastPid ! {MyPid, check_prev_done_process},
	    %% 	    receive
	    %% 		{MyPid, prev_done_process} ->
	    %% 		    ok
	    %% 	    end
	    %% end,
	    %% receive
	    %% 	{NewPid, check_prev_done_process} ->
	    %% 	    NewPid ! {NewPid, prev_done_process}
	    %% end,
	    {next_state, bad_msg, State, 0}
    end.
    %%{next_state, done_queue,State=#state{child_pid=ChildPid,prev_child_pid=LastChildPid}}.


bad_msg(timeout, State) ->
    {stop, normal, State}.
    

%% close_socket(timeout, State=#state{socket=Socket}) ->
%%     gen_tcp:close(Socket),
%%     {stop, normal, State}.

handle_info(Message, _StateName, StateData) ->
    lager:error("Recevied info:  ~p",[Message]),
    {stop,badmsg,StateData}.

handle_event(_Event, _StateName, StateData) ->
    {stop,badmsg,StateData}.

handle_sync_event(_Event, _From, _StateName, StateData) ->
    {stop,badmsg,StateData}.

code_change(_OldVsn, StateName, State, _Extra) -> {ok, StateName, State}.

terminate(_Reason, _SN, _SD) ->
    ok.
