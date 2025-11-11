/*
 * C99 CLI File Explorer
 * 
 * Compile: gcc -std=c99 -Wall -Wextra -Werror -o explorer explorer.c
 * Run: ./202413153_explorer [path]
 */

#define _POSIX_C_SOURCE 200809L
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <limits.h>
#include <errno.h>

/* Define DT_* constants if not available */
#ifndef DT_UNKNOWN
#define DT_UNKNOWN 0
#endif
#ifndef DT_DIR
#define DT_DIR 4
#endif

#define STUDENT_ID "202413153"
#define MAX_LINE 4096
#define MAX_PATH PATH_MAX

/* Forward declarations */
static int is_dir(const char *path);
static int safe_join(char *out, size_t outsz, const char *base, const char *name);
static char *normalize_path(const char *path, char *out, size_t outsz);
static void print_prompt(const char *cwd);
static void do_ls(const char *cwd);
static void do_ls_d(const char *cwd);
static void run_repl(const char *start_path);

/**
 * Check if path is a directory using lstat (doesn't follow symlinks)
 */
static int is_dir(const char *path) {
    struct stat st;
    if (lstat(path, &st) != 0) {
        return 0;
    }
    return S_ISDIR(st.st_mode);
}

/**
 * Safely join base path and name, ensuring no buffer overflow
 */
static int safe_join(char *out, size_t outsz, const char *base, const char *name) {
    if (snprintf(out, outsz, "%s/%s", base, name) >= (int)outsz) {
        return -1; /* Buffer too small */
    }
    return 0;
}

/**
 * Normalize a path by removing . and .. components and redundant slashes
 * This is a simplified version that handles common cases
 * For non-existent paths, we build a canonical form without resolving symlinks
 */
static char *normalize_path(const char *path, char *out, size_t outsz) {
    char components[MAX_PATH][MAX_PATH];
    int comp_count = 0;
    char *path_copy = strdup(path);
    char *token;
    char *saveptr;
    int is_absolute = (path[0] == '/');
    
    if (!path_copy) {
        return NULL;
    }
    
    /* Tokenize by '/' */
    token = strtok_r(path_copy, "/", &saveptr);
    while (token != NULL) {
        if (strcmp(token, ".") == 0 || strlen(token) == 0) {
            /* Skip . and empty components */
        } else if (strcmp(token, "..") == 0) {
            /* Go up one level */
            if (comp_count > 0) {
                comp_count--;
            }
        } else {
            /* Add component */
            if (comp_count < MAX_PATH) {
                strncpy(components[comp_count], token, MAX_PATH - 1);
                components[comp_count][MAX_PATH - 1] = '\0';
                comp_count++;
            }
        }
        token = strtok_r(NULL, "/", &saveptr);
    }
    
    free(path_copy);
    
    /* Reconstruct path */
    size_t pos = 0;
    out[0] = '\0';
    
    if (is_absolute) {
        /* Always start with / for absolute paths */
        if (pos < outsz - 1) {
            out[pos++] = '/';
            out[pos] = '\0';
        }
    }
    
    for (int i = 0; i < comp_count; i++) {
        size_t len = strlen(components[i]);
        if (pos + len + 1 < outsz) {
            if (is_absolute || i > 0) {
                out[pos++] = '/';
            }
            strncpy(out + pos, components[i], outsz - pos - 1);
            pos += len;
            out[pos] = '\0';
        }
    }
    
    /* If result is empty, use / for absolute or . for relative */
    if (pos == 0) {
        if (is_absolute) {
            strncpy(out, "/", outsz - 1);
            out[outsz - 1] = '\0';
        } else {
            strncpy(out, ".", outsz - 1);
            out[outsz - 1] = '\0';
        }
    }
    
    return out;
}

/**
 * Print the prompt with normalized absolute path
 */
static void print_prompt(const char *cwd) {
    char normalized[MAX_PATH];
    char abs_path[MAX_PATH];
    char *resolved;
    
    /* Get absolute path using realpath */
    resolved = realpath(cwd, abs_path);
    if (resolved == NULL) {
        /* If realpath fails, try to normalize what we have */
        if (cwd[0] == '/') {
            strncpy(abs_path, cwd, MAX_PATH - 1);
            abs_path[MAX_PATH - 1] = '\0';
        } else {
            /* Should not happen if we maintain CWD properly */
            strncpy(abs_path, ".", MAX_PATH - 1);
            abs_path[MAX_PATH - 1] = '\0';
        }
    }
    
    /* Normalize the absolute path */
    normalize_path(abs_path, normalized, sizeof(normalized));
    
    printf("*%s_explorer %s> ", STUDENT_ID, normalized);
    fflush(stdout);
}

/**
 * List directory entries (names only)
 */
static void do_ls(const char *cwd) {
    DIR *dir = opendir(cwd);
    if (dir == NULL) {
        perror(cwd);
        return;
    }
    
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        /* Skip . and .. */
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        printf("%s\n", entry->d_name);
    }
    
    closedir(dir);
}

/**
 * List directories only (ls -d)
 */
static void do_ls_d(const char *cwd) {
    DIR *dir = opendir(cwd);
    if (dir == NULL) {
        perror(cwd);
        return;
    }
    
    struct dirent *entry;
    char full_path[MAX_PATH];
    
    while ((entry = readdir(dir)) != NULL) {
        /* Skip . and .. */
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        
        /* Build full path */
        if (safe_join(full_path, sizeof(full_path), cwd, entry->d_name) != 0) {
            continue; /* Path too long */
        }
        
        /* Check if it's a directory */
        int is_directory = 0;
        
        /* Try d_type first if available */
        if (entry->d_type != DT_UNKNOWN) {
            is_directory = (entry->d_type == DT_DIR);
        } else {
            /* Fall back to stat */
            is_directory = is_dir(full_path);
        }
        
        if (is_directory) {
            printf("%s\n", entry->d_name);
        }
    }
    
    closedir(dir);
}

/**
 * Trim whitespace from the end of a string
 */
static void trim_trailing_whitespace(char *str) {
    size_t len = strlen(str);
    while (len > 0 && (str[len - 1] == ' ' || str[len - 1] == '\t' || str[len - 1] == '\n' || str[len - 1] == '\r')) {
        str[len - 1] = '\0';
        len--;
    }
}

/**
 * Tokenize input line by whitespace
 */
static int tokenize(char *line, char **tokens, int max_tokens) {
    int count = 0;
    char *token;
    char *saveptr;
    
    /* Skip leading whitespace */
    while (*line == ' ' || *line == '\t') {
        line++;
    }
    
    token = strtok_r(line, " \t", &saveptr);
    while (token != NULL && count < max_tokens) {
        tokens[count++] = token;
        token = strtok_r(NULL, " \t", &saveptr);
    }
    
    return count;
}

/**
 * Main REPL loop
 */
static void run_repl(const char *start_path) {
    char cwd[MAX_PATH];
    char line[MAX_LINE];
    char *tokens[64];
    int token_count;
    
    /* Initialize working directory */
    if (start_path != NULL && chdir(start_path) == 0) {
        if (getcwd(cwd, sizeof(cwd)) == NULL) {
            strncpy(cwd, ".", sizeof(cwd) - 1);
            cwd[sizeof(cwd) - 1] = '\0';
        }
    } else {
        if (getcwd(cwd, sizeof(cwd)) == NULL) {
            strncpy(cwd, ".", sizeof(cwd) - 1);
            cwd[sizeof(cwd) - 1] = '\0';
        }
    }
    
    /* Main loop */
    while (1) {
        print_prompt(cwd);
        
        /* Read line */
        if (fgets(line, sizeof(line), stdin) == NULL) {
            /* EOF */
            break;
        }
        
        /* Trim trailing newline */
        trim_trailing_whitespace(line);
        
        /* Skip empty lines */
        if (strlen(line) == 0) {
            continue;
        }
        
        /* Tokenize */
        token_count = tokenize(line, tokens, 64);
        if (token_count == 0) {
            continue;
        }
        
        /* Parse command */
        if (strcmp(tokens[0], "quit") == 0) {
            break;
        } else if (strcmp(tokens[0], "ls") == 0) {
            if (token_count == 1) {
                /* ls */
                do_ls(cwd);
            } else if (token_count == 2 && strcmp(tokens[1], "-d") == 0) {
                /* ls -d */
                do_ls_d(cwd);
            } else {
                /* Invalid option */
                if (token_count >= 2 && tokens[1][0] == '-') {
                    printf("Error: invalid option\n");
                } else {
                    /* Too many arguments or invalid */
                    printf("Error: invalid option\n");
                }
            }
        } else {
            /* Unknown command */
            printf("Error: unknown command\n");
        }
        
        /* Update cwd in case it changed (though we don't implement cd yet) */
        if (getcwd(cwd, sizeof(cwd)) == NULL) {
            strncpy(cwd, ".", sizeof(cwd) - 1);
            cwd[sizeof(cwd) - 1] = '\0';
        }
    }
}

/**
 * Main entry point
 */
int main(int argc, char *argv[]) {
    const char *start_path = NULL;
    
    /* Parse arguments */
    if (argc > 1) {
        start_path = argv[1];
        
        /* Try to access the path */
        if (access(start_path, F_OK) != 0) {
            perror(start_path);
            start_path = "."; /* Fall back to current directory */
        } else if (!is_dir(start_path)) {
            /* Not a directory, use parent or current */
            perror(start_path);
            start_path = ".";
        }
    }
    
    /* Run REPL */
    run_repl(start_path);
    
    return 0;
}

