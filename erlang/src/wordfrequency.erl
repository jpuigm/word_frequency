-module(wordfrequency).


-export([open_file/1]).
-export([read_content/1]).
-export([store_words/2]).
-export([top_most_frequent/2]).

-export([set_dbg/0]).

set_dbg() ->
    dbg:tracer(), dbg:p(all,c),
    dbg:tpl(wordfrequency, x).

%% Opens a file.
-spec open_file(string()) -> {ok, file:io_device()} | {error, atom()}.
open_file(Filename) ->
    file:open(Filename, [read]).

%% Reads file content from IODevice.
-spec read_content(file:io_device()) -> ok | {ok, string()} | {error, term()}.
read_content(IODevice) ->
    case io:get_line(IODevice, "") of
        {error, _} = Err ->
            Err;
        eof ->
            ok;
        Data ->
            {ok, Data}
    end.

%% Splits the content by spaces, and punctuation marks.
%% Stores words into ETS table.
-spec store_words(Data :: string(), TId :: ets:tab()) -> ok.
store_words(Data, TId) ->
    Words = string:tokens(Data, " ,;.:"),
    IndexWord = fun(Word) ->
                        case ets:member(TId, Word) of
                            true ->
                                [{Word, Frequency}] = ets:lookup(TId, Word),
                                true = ets:insert(TId, [{Word, Frequency + 1}]);
                            false ->
                                true = ets:insert(TId, [{Word, 1}])
                        end
                end,
    lists:foreach(IndexWord, Words).

-spec top_most_frequent(TId :: ets:tab(), array:array()) -> {ok, array:array()}.
top_most_frequent(TId, Array) ->
    FirstKey      = ets:first(TId),
    [FirstObject] = ets:lookup(TId, FirstKey),
    NewArray      = find_most_frequent(TId, FirstObject, Array),
    {ok, NewArray}.

%% Internal functions

-spec find_most_frequent(TId :: ets:tab(), term(), array:array()) -> array:array().
find_most_frequent(TId, {Key, _Value} = Obj0, Arr0) ->
    Array = 
        case is_frequent_enough(Obj0, Arr0) of
            {true, Pos} ->
                add_to_array(Obj0, Arr0, Pos);
            false ->
                Arr0
        end,
    case ets:next(TId, Key) of
        '$end_of_table' ->
            Array;
        NextKey ->
            [NextObject] = ets:lookup(TId, NextKey),
            find_most_frequent(TId, NextObject, Array)
    end.

-spec add_to_array(Object :: term(), array:array(), pos_integer()) -> array:array().
add_to_array(Object, Array, Position) ->
    case array:size(Array) == (Position + 1) of
        true ->
            array:set(Position, Object, Array);
        false ->
            CurrObject = array:get(Position, Array),
            NewArray = array:set(Position, Object, Array),
            add_to_array(CurrObject, NewArray, Position + 1)
    end.

-spec is_frequent_enough(Object :: term(), array:array()) -> {true, pos_integer()} | false.
is_frequent_enough(Object, Array) ->
    is_frequent_enough(Object, Array, 0).

-spec is_frequent_enough(Object :: term(), array:array(), pos_integer()) -> {true, pos_integer()} | false.
is_frequent_enough({_Word, Frequency} = Object, Array, Position) ->
    case array:size(Array) == (Position + 1) of
        true ->
            false;
        false ->
            case array:get(Position, Array) of
                {_ArrayWord, ArrayFrequency} when Frequency > ArrayFrequency ->
                    {true, Position};
                _ ->
                    is_frequent_enough(Object, Array, Position + 1)
            end
    end.
