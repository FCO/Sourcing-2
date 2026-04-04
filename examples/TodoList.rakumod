use Sourcing;

class TodoCreated is export {
    has UInt $.todo-id is required;
    has Str $.title is required;
}

class TodoCompleted is export {
    has UInt $.todo-id is required;
}

class TodoDeleted is export {
    has UInt $.todo-id is required;
}

aggregation TodoList {
    has UInt $.todo-id is required is projection-id;
    has @.items;
    has Int $.completed-count = 0;

    multi method apply(TodoCreated $e) {
        @!items.push: { title => $e.title, done => False };
    }

    multi method apply(TodoCompleted $e) {
        for @!items.kv -> $idx, $item {
            if !$item<done> {
                @!items[$idx]<done> = True;
                $!completed-count++;
                last;
            }
        }
    }

    multi method apply(TodoDeleted $e) {
        @!items = @!items.grep: *<done>;
    }

    method add(Str $title) {
        $.todo-created: title => $title;
    }

    method complete {
        $.todo-completed;
    }

    method cleanup {
        $.todo-deleted;
    }
}