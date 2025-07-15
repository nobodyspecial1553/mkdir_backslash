/*
		The origin of this program was to convert the file names of an
		erroneously zipped program. It used backslashes instead of
		forward slashes, so they unzipped as files only,
		no directories. You can use this program to take those files
		and fix the output into the correct result.

		Usage:
		--no-delete: If the input and output location are the same, the input will be deleted, passing this flag prevents that.
		-r, --recursive: Recursively descends subdirectories
		-d <string>, --output-dir <string>, --output-directory <string>: Sets output location
		-h, --help: Prints help message and exists`
*/

package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
@(require) import "core:mem"
import "core:container/queue"

main :: proc() {
	when ODIN_DEBUG {
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
		defer {
			if len(tracking_allocator.allocation_map) > 0 {
				fmt.eprint("\n--== Memory Leaks ==--\n")
				fmt.eprintf("Total Leaks: %v\n", len(tracking_allocator.allocation_map))
				for _, leak in tracking_allocator.allocation_map {
					fmt.eprintf("Leak: %v bytes @%v\n", leak.size, leak.location)
				}
			}
			if len(tracking_allocator.bad_free_array) > 0 {
				fmt.eprint("\n--== Bad Frees ==--\n")
				for bad_free in tracking_allocator.bad_free_array {
					fmt.eprintf("Bad Free: %p @%v\n", bad_free.memory, bad_free.location)
				}
			}
		}
	}

	logger_data := log.File_Console_Logger_Data {
		file_handle = os.INVALID_HANDLE,
		ident = "",
	}
	logger_lowest: log.Level = .Debug when ODIN_DEBUG else .Info
	logger_options := log.Default_Console_Logger_Opts
	context.logger = { log.file_logger_proc, &logger_data, logger_lowest, logger_options }

	/*
		 // Could reintroduce if it got more use
	arena: virtual.Arena
	arena_allocate_err := virtual.arena_init_growing(&arena)
	if arena_allocate_err != nil {
		log.panicf("Failed to allocate memory: %v", arena_allocate_err)
	}
	defer virtual.arena_destroy(&arena)
	arena_allocator := virtual.arena_allocator(&arena)
	*/

	convert_info := convert_info_create(os.args)
	convert_info.input_dir = "." if convert_info.input_dir == "" else convert_info.input_dir
	convert_info.output_dir = convert_info.input_dir if convert_info.output_dir == "" else convert_info.output_dir
	if os_err := make_directories_recursive(convert_info.output_dir); os_err != nil {
		log.fatalf("Failed to make output directory \"%s\": %v", convert_info.output_dir, os_err)
	}
	if convert_info.output_dir[len(convert_info.output_dir) - 1] == '/' {
		convert_info.output_dir = convert_info.output_dir[:len(convert_info.output_dir) - 1]
	}

	tasks: queue.Queue(string)
	queue.init(&tasks)
	defer queue.destroy(&tasks)
	queue.push_back(&tasks, convert_info.input_dir)
	
	for queue.len(tasks) != 0 {
		input_dir_path := queue.pop_front(&tasks)
		input_dir_fd, input_dir_fd_err := os.open(input_dir_path)
		if input_dir_fd_err != nil {
			log.panicf("Failed to open directory \"%s\": %v", input_dir_path, input_dir_fd_err)
		}
		defer os.close(input_dir_fd)
		if !os.is_dir(input_dir_fd) {
			log.panicf("\"%s\" is not a directory!", input_dir_path)
		}

		input_dir_file_infos, input_dir_file_infos_err := os.read_dir(input_dir_fd, -1, context.temp_allocator)
		if input_dir_file_infos_err != nil {
			log.panicf("Failed to read directory \"%s\": %v", input_dir_path, input_dir_file_infos_err)
		}

		for input_dir_file_info in input_dir_file_infos {
			if input_dir_file_info.is_dir {
				if .Recursive in convert_info.flags {
					queue.push_back(&tasks, input_dir_file_info.fullpath)
				}
				continue
			}

			last_backslash := -1
			for codepoint, index in input_dir_file_info.name {
				if codepoint == '\\' {
					last_backslash = index
				}
			}
			if last_backslash < 0 {
				continue
			}

			directory: string
			if last_backslash > 0 { // > 0 to ensure at least one letter for directory
				in_directory, _ := strings.replace_all(input_dir_file_info.name[:last_backslash], "\\", "/", context.temp_allocator)
				directory = fmt.tprintf("%s/%s", convert_info.output_dir, in_directory)
				make_directories_err := make_directories_recursive(directory)
				if make_directories_err != nil {
					log.panicf("Failed to make directories \"%s\": %v", directory, make_directories_err)
				}
			}

			if last_backslash < len(input_dir_file_info.name) - 1 { // Ensures at least one character for file name
				new_name := fmt.tprintf("%s/%s", directory, input_dir_file_info.name[last_backslash + 1:])

				if .No_Delete in convert_info.flags || convert_info.input_dir != convert_info.output_dir {
					old_file_data, old_file_data_read_success := os.read_entire_file_from_filename(input_dir_file_info.name, context.temp_allocator)
					if old_file_data_read_success == false {
						log.fatalf("Failed to read \"%s\"", input_dir_file_info.name)
					}

					new_file_fd, new_file_fd_err := os.open(new_name, os.O_WRONLY | os.O_CREATE, 0o666)
					if new_file_fd_err != nil {
						log.panicf("Failed to copy \"%s\" to \"%s\": %v", input_dir_file_info.name, new_name, new_file_fd_err)
					}
					defer os.close(new_file_fd)

					_, file_write_err := os.write(new_file_fd, old_file_data)
					if file_write_err != nil {
						log.panicf("Failed to copy \"%s\" to \"%s\": %v", input_dir_file_info.name, new_name, new_file_fd_err)
					}
					log.infof("Copied \"%s\" to \"%s\"", input_dir_file_info.name, new_name)
				}
				else {
					rename_err := os.rename(input_dir_file_info.name, new_name)
					if rename_err != nil {
						log.panicf("Failed to rename \"%s\" to \"%s\": %v", input_dir_file_info.name, new_name, rename_err)
					}
					else {
						log.infof("Renamed \"%s\" to \"%s\"", input_dir_file_info.name, new_name)
					}
				}
			}
			else {
				os.remove(input_dir_file_info.fullpath)
			}
		}

		free_all(context.temp_allocator)
	}
}

Convert_Info_Flags :: bit_set[Convert_Info_Flag]
Convert_Info_Flag :: enum {
	No_Delete,
	Recursive,
}

Convert_Info :: struct {
	input_dir: string,
	output_dir: string,
	flags: Convert_Info_Flags,
}

convert_info_create :: proc(args: []string) -> (convert_info: Convert_Info) {
	if len(args) == 1 { return }

	args := args
	args = args[1:]
	args_parse_loop: for {
		switch args[0] {
		case "--no-delete":
			convert_info.flags += { .No_Delete }
		case "-r", "--recursive":
			convert_info.flags += { .Recursive }
		case "-d", "--output-dir", "--output-directory":
			if len(args) <= 1 { return }
			args = args[1:]
			convert_info.output_dir = args[0]
		case "-h", "--help":
			print_help_message()
			os.exit(0)
		case "--":
			break args_parse_loop
		case: // Input
			convert_info.input_dir = args[0]
		}

		if len(args) <= 1 {
			break
		}
		args = args[1:]
	}
	return
}

make_directories_recursive :: proc(
	path: string,
) -> (
	os_err: os.Error,
)
{
	// Make directories
	view_start := 0
	view_end := -1
	for {
		view_start = view_end + 1
		if view_start >= len(path) { break }

		view_end = len(path)
		for codepoint, index in path[view_start:] {
			if codepoint == '/' {
				view_end = index + view_start
				break
			}
		}

		view := path[:view_end]
		if os.exists(view) {
			continue
		}
		os_err = os.make_directory(view)
		if os_err != nil {
			return
		}
	}

	return
}

print_help_message :: proc() {
	@(static, rodata)
	HELP_MSG_STRING := `Usage: %s [flags] <src_directory>
--no-delete: If the input and output location are the same, the input will be deleted, passing this flag prevents that.
-r, --recursive: Recursively descends subdirectories in the output
-d <string>, --output-dir <string>, --output-directory <string>: Sets output location
-h, --help: Prints help message and exists`

	exec_name := os.args[0]
	last_slash := 0
	for r, idx in exec_name {
		if r == '/' {
			last_slash = idx
		}
	}
	exec_name = exec_name[last_slash + 1:]

	fmt.printfln(HELP_MSG_STRING, exec_name)
}
