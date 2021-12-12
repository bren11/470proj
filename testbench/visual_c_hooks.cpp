/////////////////////////////////////////////
//
// Last update by Liran Xiao, 09/2019
//
/////////////////////////////////////////////
#include "DirectC.h"
#include <curses.h>
#include <panel.h>
#include <stdio.h>
#include <signal.h>
#include <ctype.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <string.h>

#include "riscv_inst.h"

#define PARENT_READ     readpipe[0]
#define CHILD_WRITE     readpipe[1]
#define CHILD_READ      writepipe[0]
#define PARENT_WRITE    writepipe[1]
#define NUM_HISTORY     1024
#define NUM_STAGES      5
#define NOOP_INST       0x00000013
#define NUM_REG_GROUPS  4
#define REG_SIZE_IN_HEX 8
#define INT_MAX 		32767

// random variables/stuff
int fd[2], writepipe[2], readpipe[2];
int stdout_save;
int stdout_open;
void signal_handler_IO (int status);
int wait_flag=0;
char done_state;
char echo_data;
FILE *fp;
FILE *fp2;
int setup_registers = 0;
int stop_time;
int done_time = -1;
char time_wrapped = 0;

int scale = 4;

// Struct to hold information about each register/signal group
typedef struct sig_group {
  WINDOW *win;
  PANEL *pan;
  char ****contents_4d;
  char ***contents_3d;
  char **reg_names;
  int num_entries;
  int num_regs;
  int reg_width;
  int win_height ;
  int win_col_width;
  int num_cols;
  int is_3d;
  int has_reg_names;
  int entry_num;
  int reg_num;
} sig_group_t;

// Window pointers for ncurses windows
sig_group_t btb = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=32, .num_regs=3, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t rs = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=32, .num_regs=14, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t cdb = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=6, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t func_add = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=16, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t func_mult = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=16, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t func_branch = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=16, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t func_mem = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=16, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t if0 = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=6, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t if_id = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=3, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t id = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=14, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t id_ex = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=17, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t misc = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=1, .num_regs=10, .reg_width=11,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=1, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t rob = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=32, .num_regs=12, .reg_width=9,
	 				.win_height=32, .win_col_width=0, .num_cols=2, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t rob_signal = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=10, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t rob_misc = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=1, .num_regs=5, .reg_width=11,
					.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=1, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t prf = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=0, .num_regs=4, .reg_width=8,
					.win_height=34, .win_col_width=0, .num_cols=2, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t rat = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=32, .num_regs=32, .reg_width=6,
					.win_height=16, .win_col_width=0, .num_cols=2, .is_3d=1, .has_reg_names=0, .entry_num=0, .reg_num=0 };

sig_group_t rrat = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=32, .num_regs=32, .reg_width=6,
					.win_height=16, .win_col_width=0, .num_cols=2, .is_3d=1, .has_reg_names=0, .entry_num=0, .reg_num=0 };

sig_group_t lsq_load = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=12, .num_regs=11, .reg_width=9,
					.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t lsq_store = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=8, .num_regs=9, .reg_width=9,
					.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

sig_group_t lsq_in = {.win=0, .pan=0, .contents_4d=0, .contents_3d=0, .reg_names=0, .num_entries=scale, .num_regs=4, .reg_width=9,
	 				.win_height=INT_MAX, .win_col_width=0, .num_cols=1, .is_3d=0, .has_reg_names=1, .entry_num=0, .reg_num=0 };

WINDOW *title_win;
WINDOW *time_win;
WINDOW *sim_time_win;
WINDOW *instr_win;
WINDOW *clock_win;

// arrays for register contents and names
int history_num=0;

char readbuffer[1024];
char **timebuffer;
char **cycles;
char *clocks;
char *resets;
char **inst_contents;

//variables for panel management
int cur_pan = 0;
char *panel_titles[] = {"IF","ID","RS","ROB","FUNC","LSQ"};
int title_offset = 22;

char *get_opcode_str(int inst, int valid_inst);
void parse_register(char* readbuf, int reg_num, char*** contents, char** reg_names);
void parse_register_superscaler(char *readbuf, int reg_num, char**** contents, char** reg_names, int width);
int get_time();


// Helper function for ncurses gui setup
WINDOW *create_newwin(int height, int width, int starty, int startx, int color){
  WINDOW *local_win;
  local_win = newwin(height, width, starty, startx);
  wbkgd(local_win,COLOR_PAIR(color));
  wattron(local_win,COLOR_PAIR(color));
  box(local_win,0,0);
  wrefresh(local_win);
  return local_win;
}

// Function to draw positive edge or negative edge in clock window
void update_clock(char clock_val){
  static char cur_clock_val = 0;
  // Adding extra check on cycles because:
  //  - if the user, right at the beginning of the simulation, jumps to a new
  //    time right after a negative clock edge, the clock won't be drawn
  if((clock_val != cur_clock_val) || strncmp(cycles[history_num],"      0",7) == 1){
    mvwaddch(clock_win,3,7,ACS_VLINE | A_BOLD);
    if(clock_val == 1){

      //we have a posedge
      mvwaddch(clock_win,2,1,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,ACS_ULCORNER | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      mvwaddch(clock_win,4,1,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_LRCORNER | A_BOLD);
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
    } else {

      //we have a negedge
      mvwaddch(clock_win,4,1,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,ACS_LLCORNER | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      mvwaddch(clock_win,2,1,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_HLINE | A_BOLD);
      waddch(clock_win,ACS_URCORNER | A_BOLD);
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
      waddch(clock_win,' ');
    }
  }
  cur_clock_val = clock_val;
  wrefresh(clock_win);
}

void switch_tabs(int next_tab){
	switch (cur_pan){
    case 0:
	    hide_panel(btb.pan);
		hide_panel(if0.pan);
		hide_panel(if_id.pan);
		break;
    case 1:
		hide_panel(id.pan);
		hide_panel(id_ex.pan);
		break;
	case 2:
		hide_panel(rs.pan);
		break;
	case 3:
		hide_panel(rob.pan);
		hide_panel(rob_signal.pan);
		hide_panel(rob_misc.pan);
		break;
	case 4:
		hide_panel(func_add.pan);
		hide_panel(func_mult.pan);
		hide_panel(func_branch.pan);
		hide_panel(func_mem.pan);
		break;
	case 5:
		hide_panel(lsq_load.pan);
		hide_panel(lsq_store.pan);
		hide_panel(lsq_in.pan);
		break;
	}
	switch (next_tab) {
		case 0:
			show_panel(btb.pan);
			show_panel(if0.pan);
			show_panel(if_id.pan);
			break;
		case 1:
			show_panel(id.pan);
			show_panel(id_ex.pan);
			break;
		case 2:
			show_panel(rs.pan);
			break;
		case 3:
			show_panel(rob.pan);
			show_panel(rob_signal.pan);
			show_panel(rob_misc.pan);
			break;
		case 4:
			show_panel(func_add.pan);
			show_panel(func_mult.pan);
			show_panel(func_branch.pan);
			show_panel(func_mem.pan);
			break;
		case 5:
			show_panel(lsq_load.pan);
			show_panel(lsq_store.pan);
			show_panel(lsq_in.pan);
			break;
	}
	int offset = title_offset;
	for(int i =0; i<6;i++ ){
		if(i == next_tab)
			wattron(title_win, A_REVERSE);
		mvwprintw(title_win,1,COLS-offset,panel_titles[i]);
		wattroff(title_win, A_REVERSE);
		offset -= strlen(panel_titles[i]);
		if(i<5){
			mvwprintw(title_win,1,COLS-offset,"|");
			offset -=1;
		}
	}
	cur_pan = next_tab;
    wrefresh(title_win);
	update_panels();
	doupdate();
}

void init_window(WINDOW* window, int win_width, int win_height,int reg_width, char* win_title, int num_digits,
					int num_cols, int col_width, bool print_hash, bool print_num){
	mvwprintw(window,0, (win_width-strlen(win_title))/2,win_title);
	int offset = print_hash ? 2 : 1;
	char tmp_buf[32];
	if(print_num){
		wattron(window,A_UNDERLINE);
		int j=0;
	    for(;j<num_cols;j++){
			if(print_hash)
				mvwprintw(window,1,(reg_width/2)+(j*col_width), "#");
		    int i=0;
		    for (; i < win_height; i++) {
				if(num_digits == 1)
		  			sprintf(tmp_buf, "x%01X", (j*win_height)+i);
				else
		  			sprintf(tmp_buf, "x%02X", (j*win_height)+i);
		  	  	mvwprintw(window,i+offset,(reg_width/2)-1+(j*col_width),tmp_buf);
	      	}
	    }
	    wattroff(window,A_UNDERLINE);
	}
}

// Function to create and initialize the gui
// Color pairs are (foreground color, background color)
// If you don't like the dark backgrounds, a safe bet is to have
//   COLOR_BLUE/BLACK foreground and COLOR_WHITE background
void setup_gui(FILE *fp){
  initscr();
  if(has_colors()){
    start_color();
    init_pair(1,COLOR_CYAN,COLOR_BLACK);    // shell background
    init_pair(2,COLOR_YELLOW,COLOR_RED);
    init_pair(3,COLOR_RED,COLOR_BLACK);
    init_pair(4,COLOR_YELLOW,COLOR_BLUE);   // title window
    init_pair(5,COLOR_YELLOW,COLOR_BLACK);  // register/signal windows
    init_pair(6,COLOR_RED,COLOR_BLACK);
    init_pair(7,COLOR_MAGENTA,COLOR_BLACK); // pipeline window
    init_pair(8,COLOR_BLUE, COLOR_BLACK);
  }
  curs_set(0);
  noecho();
  cbreak();
  keypad(stdscr,TRUE);
  wbkgd(stdscr,COLOR_PAIR(1));
  wrefresh(stdscr);
  int pipe_width=0;

  //instantiate the title window at top of screen
  title_win = create_newwin(3,COLS,0,0,4);
  mvwprintw(title_win,1,1,"SIMULATION INTERFACE V2");

  //instantiate time window at right hand side of screen
  time_win = create_newwin(3,10,3,COLS-10,5);
  mvwprintw(time_win,0,3,"TIME");
  wrefresh(time_win);

  //instantiate a sim time window which states the actual simlator time
  sim_time_win = create_newwin(3,10,6,COLS-10,5);
  mvwprintw(sim_time_win,0,1,"SIM TIME");
  wrefresh(sim_time_win);

  //instantiate a window to show which clock edge this is
  clock_win = create_newwin(6,15,3,COLS-25,5);
  mvwprintw(clock_win,0,5,"CLOCK");
  mvwprintw(clock_win,1,1,"cycle:");
  update_clock(0);
  wrefresh(clock_win);

  // instantiate a window for the PRF on the right side
  prf.num_cols = (prf.num_entries + prf.win_height -1) / prf.win_height;
  prf.win_col_width = ((prf.num_regs-1)*2) + 13;
  int prf_win_width = prf.win_col_width * prf.num_cols + 1;
  prf.win = create_newwin(prf.win_height + 3,prf_win_width,9,COLS-prf_win_width,5);
  mvwprintw(prf.win,0,prf_win_width/2,"PRF");
  wattron(prf.win,A_UNDERLINE);
  mvwprintw(prf.win,1,2,"#");
  mvwprintw(prf.win,1,2+prf.win_col_width,"#");
  int i=0;
  char tmp_buf[32];
  for (; i < prf.win_height; i++) {
  	int j=0;
	for(;j<prf.num_cols;j++){
	  sprintf(tmp_buf, "x%02X", (j*prf.win_height)+i);
	  mvwprintw(prf.win,i+2,1+(j*prf.win_col_width),tmp_buf);
	}
  }
  wattroff(prf.win,A_UNDERLINE);
  wrefresh(prf.win);

  //Instantiating BTB window
  int btb_width = (btb.num_regs+1)*btb.reg_width;
  btb.win = create_newwin(btb.num_entries + 3, btb_width,3,0,5);
  btb.pan = new_panel(btb.win);
  init_window(btb.win, (btb.num_regs+1)*btb.reg_width, btb.num_entries, btb.reg_width, "BTB", 1, 1, 0,true, true);
  wrefresh(btb.win);

  //instantiate window to visualize IF stage (including IF/ID)
  if0.win = create_newwin(scale + 3, (if0.num_regs+1)*if0.reg_width,3,btb_width,5);
  if0.pan = new_panel(if0.win);
  init_window(if0.win, (if0.num_regs+1)*if0.reg_width, scale, if0.reg_width, "IF STAGE", 1, 1, 0,true, true);
  wrefresh(if0.win);

  //instantiate window to visualize IF/ID signals
  if_id.win = create_newwin(scale + 3, (if_id.num_regs+1)*id_ex.reg_width, 3 + scale + 3,btb_width,5);
  if_id.pan = new_panel(if_id.win);
  init_window(if_id.win, (if_id.num_regs+1)*if_id.reg_width, scale, if_id.reg_width, "IF/ID STAGE", 1, 1, 0,true, true);
  wrefresh(if_id.win);

  //instantiate a window to visualize ID stage
  id.win = create_newwin(scale + 3, (id.num_regs+1)*id.reg_width,3 ,0,5);
  id.pan = new_panel(id.win);
  hide_panel(id.pan);
  init_window(id.win, (id.num_regs+1)*id.reg_width, scale, id.reg_width, "ID STAGE", 1, 1, 0,true, true);

  //instantiate a window to visualize ID/EX signals
  id_ex.win = create_newwin(scale + 3, (id_ex.num_regs+1)*id_ex.reg_width,3 + ((scale + 3)),0,5);
  id_ex.pan = new_panel(id_ex.win);
  hide_panel(id_ex.pan);
  init_window(id_ex.win, (id_ex.num_regs+1)*id_ex.reg_width, scale, id_ex.reg_width, "ID/EX STAGE", 1, 1, 0,true, true);

  //instantiate a window to visualize RAT
  rat.num_cols = (rat.num_entries + rat.win_height - 1)/rat.win_height;
  rat.win_col_width = rat.reg_width * 2;
  int rat_win_width =  (rat.win_col_width * rat.num_cols) + 2;
  rat.win = create_newwin(rat.win_height + 2,rat_win_width, LINES-rat.win_height-2,0,5);
  init_window(rat.win, rat_win_width, rat.win_height, rat.reg_width, "RAT", 2, 2, rat.reg_width*2,false, true);
  wrefresh(rat.win);

  //instantiate a window to visualize RAT
  rrat.win_col_width = rrat.reg_width * 2;
  rrat.win = create_newwin(rat.win_height + 2,rat_win_width, LINES-rrat.win_height-2,rat_win_width,5);
  init_window(rrat.win, rat_win_width, rat.win_height, rrat.reg_width, "RRAT", 2, 2, rrat.reg_width*2,false, true);
  wrefresh(rrat.win);

  //instantiate a window to visualize RS
  rs.win = create_newwin((rs.num_entries+3),rs.reg_width*(rs.num_regs+1),3,0,5);
  rs.pan = new_panel(rs.win);
  hide_panel(rs.pan);
  init_window(rs.win, rs.reg_width*(rs.num_regs+1), rs.num_entries, rs.reg_width,
   				"RESERVATION STATION", 2, 1, 0,true, true);

  // instantiating a window to visualize rob state
  rob.num_cols = (rob.num_entries + rob.win_height - 1)/rob.win_height;
  rob.win_col_width = rob.reg_width * (rob.num_regs+1);
  int rob_win_width = (rob.win_col_width * rob.num_cols) + 2;
  rob.win = create_newwin(rob.win_height+3,rob_win_width,3,0,5);
  rob.pan = new_panel(rob.win);
  hide_panel(rob.pan);
  init_window(rob.win, rob_win_width, rob.win_height, rob.reg_width,"ROB-STATE", 2, 2, rob.win_col_width,true, true);

  //instantiating a window to wisualize rob outputs
  rob_signal.win = create_newwin(scale+3,(rob_signal.num_regs +1) * rob_signal.reg_width,LINES-18,52,5);
  rob_signal.pan = new_panel(rob_signal.win);
  hide_panel(rob_signal.pan);
  init_window(rob_signal.win, (rob_signal.num_regs +1) * rob_signal.reg_width, scale, rob_signal.reg_width,
  				"ROB-OUTPUTS", 1, 1, 0,true, true);

  //instantiating a window to wisualize rob outputs
  rob_misc.win = create_newwin(rob_misc.num_regs+2, (2*rob_misc.reg_width)+3,LINES-(rob_misc.num_regs+2),52,5);
  rob_misc.pan = new_panel(rob_misc.win);
  hide_panel(rob_misc.pan);
  mvwprintw(rob_misc.win,0,(2*rob_misc.reg_width)/2 - 4,"ROB-MISC");

  //instantiate a window to visualize CDB
  cdb.win = create_newwin((scale+3),cdb.reg_width*(cdb.num_regs+1),LINES-scale-3,COLS-55-(cdb.reg_width*(cdb.num_regs+1)),5);
  init_window(cdb.win, cdb.reg_width*(cdb.num_regs+1), scale, cdb.reg_width, "CDB", 1, 1, 0,true, true);
  wrefresh(cdb.win);

  int func_add_win_width = func_add.reg_width*(func_add.num_regs+1);
  func_add.win = create_newwin((scale+3),func_add_win_width,3,0,5);
  func_add.pan = new_panel(func_add.win);
  hide_panel(func_add.pan);
  init_window(func_add.win, func_add_win_width, scale, func_add.reg_width, "FUNC-ADD", 1, 1, 0,true, true);

  int func_mult_win_width = func_mult.reg_width*(func_mult.num_regs+1);
  func_mult.win = create_newwin((scale+3),func_mult_win_width,3 + ((3+scale)*1),0,5);
  func_mult.pan = new_panel(func_mult.win);
  hide_panel(func_mult.pan);
  init_window(func_mult.win, func_mult_win_width, scale, func_mult.reg_width, "FUNC-MULT", 1, 1, 0,true, true);

  int func_branch_win_width = func_branch.reg_width*(func_branch.num_regs+1);
  func_branch.win = create_newwin((scale+3),func_branch_win_width,3 + ((3+scale)*2),0,5);
  func_branch.pan = new_panel(func_branch.win);
  hide_panel(func_branch.pan);
  init_window(func_branch.win, func_branch_win_width, scale, func_branch.reg_width, "FUNC-BRANCH", 1, 1, 0,true, true);

  int func_mem_win_width = func_mem.reg_width*(func_mem.num_regs+1);
  func_mem.win = create_newwin((scale+3),func_mem_win_width,3 + ((3+scale)*3),0,5);
  func_mem.pan = new_panel(func_mem.win);
  hide_panel(func_mem.pan);
  init_window(func_mem.win, func_mem_win_width, scale, func_mem.reg_width, "FUNC-MEM", 1, 1, 0,true, true);

  int lsq_store_win_width = lsq_store.reg_width*(lsq_store.num_regs+1);
  lsq_store.win = create_newwin((lsq_store.num_entries+3),lsq_store_win_width,3,0,5);
  lsq_store.pan = new_panel(lsq_store.win);
  hide_panel(lsq_store.pan);
  init_window(lsq_store.win, lsq_store_win_width, lsq_store.num_entries, lsq_store.reg_width, "LSQ-STORE-QUEUE", 1, 1, 0,true, true);

  int lsq_load_win_width = lsq_load.reg_width*(lsq_load.num_regs+1);
  lsq_load.win = create_newwin((lsq_load.num_entries+3),lsq_load_win_width,3+ (lsq_store.num_entries+3),0,5);
  lsq_load.pan = new_panel(lsq_load.win);
  hide_panel(lsq_load.pan);
  init_window(lsq_load.win, lsq_load_win_width, lsq_load.num_entries, lsq_load.reg_width, "LSQ-LOAD-QUEUE", 1, 1, 0,true, true);

  //instantiating a window to wisualize lsq outputs
  lsq_in.win = create_newwin(scale+3,(lsq_in.num_regs +1) * lsq_in.reg_width,LINES-18,52,5);
  lsq_in.pan = new_panel(lsq_in.win);
  hide_panel(lsq_in.pan);
  init_window(lsq_in.win, (lsq_in.num_regs +1) * lsq_in.reg_width, scale, lsq_in.reg_width,	"LSQ_IN", 1, 1, 0,true, true);

  //instantiate an instructional window to help out the user some
  instr_win = create_newwin(8,30,LINES-8,COLS-30,5);
  mvwprintw(instr_win,0,9,"INSTRUCTIONS");
  wattron(instr_win,COLOR_PAIR(5));
  mvwaddstr(instr_win,1,1,"'n'   -> Next clock edge");
  mvwaddstr(instr_win,2,1,"'b'   -> Previous clock edge");
  mvwaddstr(instr_win,3,1,"'c/g' -> Goto specified time");
  mvwaddstr(instr_win,4,1,"'r'   -> Run to end of sim");
  mvwaddstr(instr_win,5,1,"'q'   -> Quit Simulator");
  mvwaddstr(instr_win,6,1,"'1-6' -> Change Tab");
  wrefresh(instr_win);

  // instantiate window to visualize misc regs/wires
  misc.win = create_newwin(misc.num_regs + 2,25,LINES-(misc.num_regs + 2),COLS-55,5);
  mvwprintw(misc.win,0,10,"MISC");
  wrefresh(misc.win);

  switch_tabs(0);
  refresh();
}

void vertical_update(sig_group_t group, int history_num_in, int old_history_num_in, int has_inst) {
	char *opcode;
	int tmp=0;
	int tmp_val=0;
	for(int i=0;i<group.num_regs;i++){
		for(int j=0;j<group.num_entries;j++){
			int col_offset = (j/group.win_height) * group.win_col_width;
			if (strcmp(group.contents_4d[history_num_in][j][i], group.contents_4d[old_history_num_in][j][i]))
				wattron(group.win, A_REVERSE);
			else
				wattroff(group.win, A_REVERSE);

			if((i == 1) && (has_inst)){
				tmp = (int)group.contents_4d[history_num_in][j][i][8] - (int)'0';
				sscanf(group.contents_4d[history_num_in][j][i],"%8x", &tmp_val);
				opcode = get_opcode_str(tmp_val, tmp);
				mvwprintw(group.win,(j%group.win_height)+2,(group.reg_width*(i+1)) + col_offset,"          ");
				mvwaddstr(group.win,(j%group.win_height)+2,(group.reg_width*(i+1)) + col_offset, opcode);
			}
			else
				mvwaddstr(group.win,(j%group.win_height)+2,(group.reg_width*(i+1)) + col_offset, group.contents_4d[history_num_in][j][i]);
		}
	}

}

void horizontal_update(sig_group_t group, int offset, int history_num_in, int old_history_num_in) {
    for(int i=0;i<group.num_regs;i++){
		int col_offset = (i/group.win_height) * group.win_col_width;
		if (strcmp(group.contents_3d[history_num_in][i], group.contents_3d[old_history_num_in][i]))
			wattron(group.win, A_REVERSE);
		else
			wattroff(group.win, A_REVERSE);
		mvwaddstr(group.win,(i%group.win_height)+offset,group.reg_width + col_offset, group.contents_3d[history_num_in][i]);
	}
}


// This function updates all of the signals being displayed with the values
// from time history_num_in (this is the index into all of the data arrays).
// If the value changed from what was previously display, the signal has its
// display color inverted to make it pop out.
void parsedata(int history_num_in){
  static int old_history_num_in=0;
  static int old_head_position=0;
  static int old_tail_position=0;
  int i=0;
  int j=0;
  int data_counter=0;
  char *opcode;
  int tmp=0;
  int tmp_val=0;
  char tmp_buf[32];
  int pipe_width = COLS/6;

  // Handle updating resets
  if (resets[history_num_in]) {
    wattron(title_win,A_REVERSE);
    mvwprintw(title_win,1,(COLS/2)-3,"RESET");
    wattroff(title_win,A_REVERSE);
  }
  else if (done_time != 0 && (history_num_in == done_time)) {
    wattron(title_win,A_REVERSE);
    mvwprintw(title_win,1,(COLS/2)-3,"DONE ");
    wattroff(title_win,A_REVERSE);
  }
  else
    mvwprintw(title_win,1,(COLS/2)-3,"     ");
  wrefresh(title_win);

  // Handle updating the PRF window
  for(i=0;i<prf.num_regs;i++){
	  for(j=0;j<prf.num_entries;j++){
		int col_offset = (j/prf.win_height) * prf.win_col_width;
	    if (strcmp(prf.contents_4d[history_num_in][j][i],
	                prf.contents_4d[old_history_num_in][j][i]))
	      wattron(prf.win, A_REVERSE);
	    else
	      wattroff(prf.win, A_REVERSE);
	    mvwaddstr(prf.win,(j%prf.win_height)+2,col_offset + (2*i) + 5,prf.contents_4d[history_num_in][j][i]);
	}
  }
  wrefresh(prf.win);

  // Updating CDB window
  vertical_update(cdb, history_num_in, old_history_num_in, 0);
  wrefresh(cdb.win);

  // Handle updating the RS window
  vertical_update(rs, history_num_in, old_history_num_in, 1);
  if(cur_pan == 2)
  	wrefresh(rs.win);

  // Updating the ROB
  vertical_update(rob, history_num_in, old_history_num_in, 1);
  if(cur_pan == 3)
  	wrefresh(rob.win);
  vertical_update(rob_signal, history_num_in, old_history_num_in, 0);
  if(cur_pan == 3)
  	wrefresh(rob_signal.win);
  horizontal_update(rob_misc,1, history_num_in, old_history_num_in);
  if(cur_pan == 3)
  	wrefresh(rob_misc.win);

  // Handle updating the IF window
  vertical_update(if0, history_num_in, old_history_num_in, 0);
  if(cur_pan == 0)
  	wrefresh(if0.win);

  // Handle updating the BTB window
  vertical_update(btb, history_num_in, old_history_num_in, 0);
  if(cur_pan == 0)
  	wrefresh(btb.win);

  // Handle updating the IF/ID window
  vertical_update(if_id, history_num_in, old_history_num_in, 0);
  if(cur_pan == 0)
  	wrefresh(if_id.win);

  // Handle updating the ID window
  vertical_update(id, history_num_in, old_history_num_in, 0);
  if(cur_pan == 1)
  	wrefresh(id.win);

  // Handle updating the ID/EX window
  vertical_update(id_ex, history_num_in, old_history_num_in, 0);
  if(cur_pan == 1)
  	wrefresh(id_ex.win);

  // Handle updating the Func_add window
  vertical_update(func_add, history_num_in, old_history_num_in, 0);
  if(cur_pan == 4)
  	wrefresh(func_add.win);

  // Handle updating the Func_mult window
  vertical_update(func_mult, history_num_in, old_history_num_in, 0);
  if(cur_pan == 4)
  	wrefresh(func_mult.win);

  // Handle updating the Func_branch window
  vertical_update(func_branch, history_num_in, old_history_num_in, 0);
  if(cur_pan == 4)
  	wrefresh(func_branch.win);

  // Handle updating the Func_mem window
  vertical_update(func_mem, history_num_in, old_history_num_in, 0);
  if(cur_pan == 4)
  	wrefresh(func_mem.win);

  // Handle updating the LSQ Load window
  vertical_update(lsq_load, history_num_in, old_history_num_in, 0);
  if(cur_pan == 5)
  	wrefresh(lsq_load.win);

  // Handle updating the LSQ Load window
  vertical_update(lsq_store, history_num_in, old_history_num_in, 0);
  if(cur_pan == 5)
  	wrefresh(lsq_store.win);

  // Handle updating the LSQ in window
  vertical_update(lsq_in, history_num_in, old_history_num_in, 0);
  if(cur_pan == 5)
  	wrefresh(lsq_in.win);
  //
  // Handle updating the RAT window
  horizontal_update(rat, 1, history_num_in, old_history_num_in);
  wrefresh(rat.win);

  // Handle updating the RRAT window
  horizontal_update(rrat,1, history_num_in, old_history_num_in);
  wrefresh(rrat.win);
  //
  // Updating the misc window
  horizontal_update(misc, 1, history_num_in, old_history_num_in);
  wrefresh(misc.win);

  //update the time window
  mvwaddstr(time_win,1,1,timebuffer[history_num_in]);
  wrefresh(time_win);

  //update to the correct clock edge for this history
  mvwaddstr(clock_win,1,7,cycles[history_num_in]);
  update_clock(clocks[history_num_in]);

  //save the old history index to check for changes later
  old_history_num_in = history_num_in;
}

void copy_input_horizontal(sig_group_t *group, char* buffer,int setup_registers,int history_num){
	int tmp_len;
    int pipe_idx;
    char name_buf[32];
    char val_buf[32];
	if ((!setup_registers) && (group->entry_num == 0)) {
		parse_register_superscaler(buffer, group->reg_num, group->contents_4d, group->reg_names, group->num_entries);
		wattron(group->win,A_UNDERLINE);
		for (int col=0; col < group->num_cols; col++){
			mvwaddstr(group->win,1,(group->reg_num+1)*group->reg_width + (group->win_col_width * col),group->reg_names[group->reg_num]);
		}
		wattroff(group->win,A_UNDERLINE);
	} else {
		sscanf(buffer,"%*c%s %d:%d:%s",name_buf,&pipe_idx,&tmp_len,val_buf);
		strcpy(group->contents_4d[history_num][pipe_idx][group->reg_num],val_buf);
	}

	group->entry_num += ((group->reg_num+1) / group->num_regs);
	group->reg_num   = ((group->reg_num+1) % group->num_regs);
}

void copy_input_vertical(sig_group_t *group, char* buffer,int setup_registers, int history_num){
	int tmp_len;
	int pipe_idx;
	char name_buf[32];
	char val_buf[32];
	if (!setup_registers) {
		parse_register(buffer, group->reg_num, group->contents_3d, group->reg_names);
		mvwaddstr(group->win,group->reg_num+1,1,group->reg_names[group->reg_num]);
	  	waddstr(group->win, ": ");
	} else {
		sscanf(buffer,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
		strcpy(group->contents_3d[history_num][group->reg_num],val_buf);
	}
	group->reg_num = ((group->reg_num+1) % group->num_regs);
}


// Parse a line of data output from the testbench
int processinput(){
  static int byte_num = 0;

  static int func_mult_pipe_num = 0;
  static int func_mult_reg_num = 0;
  static int func_mem_pipe_num = 0;
  static int func_mem_reg_num = 0;
  int tmp_len;
  int pipe_idx;
  char name_buf[32];
  char val_buf[32];

  //get rid of newline character
  readbuffer[strlen(readbuffer)-1] = 0;

  if(strncmp(readbuffer,"t",1) == 0){

    //We are getting the timestamp
    strcpy(timebuffer[history_num],readbuffer+1);
  }else if(strncmp(readbuffer,"c",1) == 0){

    //We have a clock edge/cycle count signal
    if(strncmp(readbuffer+1,"0",1) == 0)
      clocks[history_num] = 0;
    else
      clocks[history_num] = 1;

    // grab clock count (for some reason, first clock count sent is
    // too many digits, so check for this)
    strncpy(cycles[history_num],readbuffer+2,7);
    if (strncmp(cycles[history_num],"       ",7) == 0)
      cycles[history_num][6] = '0';

  }else if(strncmp(readbuffer,"z",1) == 0){

    // we have a reset signal
    if(strncmp(readbuffer+1,"0",1) == 0)
      resets[history_num] = 0;
    else
      resets[history_num] = 1;

  }else if(strncmp(readbuffer,"a",1) == 0){
    // We are getting PRF registers
	if ((!setup_registers) && (prf.entry_num == 0)) {
	   parse_register_superscaler(readbuffer, prf.reg_num, prf.contents_4d, prf.reg_names, prf.num_entries);
	   wattron(prf.win,A_UNDERLINE);
	   for (int col=0; col < prf.num_cols; col++){
	   	 mvwaddstr(prf.win,1,(prf.reg_num*2)+5+(prf.win_col_width * col),prf.reg_names[prf.reg_num]);
       }
	   wattroff(prf.win,A_UNDERLINE);
	   wrefresh(prf.win);
	 } else {
	   sscanf(readbuffer,"%*c%s %d:%d:%s",name_buf,&pipe_idx,&tmp_len,val_buf);
	   strcpy(prf.contents_4d[history_num][pipe_idx][prf.reg_num],val_buf);
	 }

	 prf.entry_num += ((prf.reg_num+1) / prf.num_regs);
	 prf.reg_num    = ((prf.reg_num+1) % prf.num_regs);

	}else if(strncmp(readbuffer,"C",1) == 0){
		// We are getting CDB registers
		copy_input_horizontal(&cdb, readbuffer, setup_registers, history_num);
  	}else if(strncmp(readbuffer,"r",1) == 0){
     	// We are getting RS registers
		 copy_input_horizontal(&rs, readbuffer, setup_registers, history_num);
   }else if(strncmp(readbuffer,"R",1) == 0){
      // We are getting ROB state
	  if(strncmp(readbuffer+1,"s",1) == 0){
		 copy_input_horizontal(&rob, readbuffer+1, setup_registers, history_num);
	 }
	 else if(strncmp(readbuffer+1,"S",1) == 0){
		 copy_input_horizontal(&rob_signal, readbuffer+1, setup_registers, history_num);
	 }
	 else if(strncmp(readbuffer+1,"m",1) == 0){
		 copy_input_vertical(&rob_misc, readbuffer+1, setup_registers, history_num);
	 }

  }else if(strncmp(readbuffer,"p",1) == 0){
    // We are getting information about which instructions are in each stage
    strcpy(inst_contents[history_num], readbuffer+1);

  	}else if(strncmp(readbuffer,"f",1) == 0){
    	// We are getting an IF register
    	copy_input_horizontal(&if0, readbuffer, setup_registers, history_num);
	}else if(strncmp(readbuffer,"B",1) == 0){
	    // Reading BTB state
	    copy_input_horizontal(&btb, readbuffer, setup_registers, history_num);
  	}else if(strncmp(readbuffer,"g",1) == 0){
	    // We are getting an IF/ID register
		copy_input_horizontal(&if_id, readbuffer, setup_registers, history_num);
  	}else if(strncmp(readbuffer,"d",1) == 0){
	    // We are getting an ID register
		copy_input_horizontal(&id, readbuffer, setup_registers, history_num);
  	}else if(strncmp(readbuffer,"h",1) == 0){
	    // We are getting an ID/EX register
		copy_input_horizontal(&id_ex, readbuffer, setup_registers, history_num);
  }else if(strncmp(readbuffer,"k",1) == 0){
	  sscanf(readbuffer,"%*c %s",val_buf);
      strcpy(rat.contents_3d[history_num][rat.entry_num],val_buf);
	  rat.entry_num++;
  }else if(strncmp(readbuffer,"K",1) == 0){
	  sscanf(readbuffer,"%*c %s",val_buf);
      strcpy(rrat.contents_3d[history_num][rrat.entry_num],val_buf);
	  rrat.entry_num++;
  }else if(strncmp(readbuffer,"F",1) == 0){
	  if (strncmp(readbuffer+1,"a",1) == 0){
	  	copy_input_horizontal(&func_add, readbuffer+1, setup_registers, history_num);
	} else if (strncmp(readbuffer+1,"b",1) == 0){
		copy_input_horizontal(&func_branch, readbuffer+1, setup_registers, history_num);
    } else if (strncmp(readbuffer+1,"c",1) == 0){
		copy_input_horizontal(&func_mult, readbuffer+1,setup_registers, history_num);
    } else if (strncmp(readbuffer+1,"d",1) == 0){
		copy_input_horizontal(&func_mem, readbuffer+1,setup_registers, history_num);
    }
	}else if(strncmp(readbuffer,"L",1) == 0){
	  	if (strncmp(readbuffer+1,"l",1) == 0){
	  		copy_input_horizontal(&lsq_load, readbuffer+1, setup_registers, history_num);
		} else if (strncmp(readbuffer+1,"s",1) == 0){
			copy_input_horizontal(&lsq_store, readbuffer+1, setup_registers, history_num);
	    } else if(strncmp(readbuffer+1,"i",1) == 0){
   		 	copy_input_horizontal(&lsq_in, readbuffer+1, setup_registers, history_num);
   	 	}
  }else if(strncmp(readbuffer,"v",1) == 0){

    //we are processing misc register/wire data
    copy_input_vertical(&misc, readbuffer, setup_registers, history_num);
  }else if (strncmp(readbuffer,"break",4) == 0) {
    // If this is the first time through, indicate that we've setup all of
    // the register arrays.
    setup_registers = 1;

    //we've received our last data segment, now go process it
    byte_num = 0;
	if0.entry_num = 0;
    if0.reg_num = 0;
    if_id.entry_num = 0;
    if_id.reg_num = 0;
    id.entry_num = 0;
    id.reg_num = 0;
    id_ex.entry_num = 0;
    id_ex.reg_num = 0;
	misc.reg_num = 0;

	cdb.entry_num = 0;
    cdb.reg_num = 0;
    rs.entry_num = 0;
    rs.reg_num = 0;

    rob.entry_num = 0;
    rob.reg_num = 0;
    rob_signal.entry_num = 0;
    rob_signal.reg_num = 0;
    rob_misc.reg_num = 0;

    prf.entry_num = 0;
    prf.reg_num = 0;
    rat.entry_num = 0;
    rrat.entry_num = 0;

    func_add.entry_num = 0;
    func_add.reg_num = 0;
    func_branch.entry_num = 0;
    func_branch.reg_num = 0;
    func_mult.entry_num = 0;
    func_mult.reg_num = 0;
    func_mem.entry_num = 0;
    func_mem.reg_num = 0;

	btb.entry_num = 0;
	btb.reg_num = 0;

	lsq_load.entry_num = 0;
	lsq_load.reg_num = 0;
	lsq_store.entry_num = 0;
	lsq_store.reg_num = 0;
	lsq_in.reg_num = 0;

    //update the simulator time, this won't change with 'b's
    mvwaddstr(sim_time_win,1,1,timebuffer[history_num]);
    wrefresh(sim_time_win);

    //tell the parent application we're ready to move on
    return(1);
  }
  return(0);
}

void init_sig_group(sig_group_t *group){
	if(group->has_reg_names)
		group->reg_names = (char**) malloc(group->num_regs*sizeof(char*));

	if(group->is_3d == 1){
		group->contents_3d = (char***) malloc(NUM_HISTORY*sizeof(char**));
		for(int i =0; i< NUM_HISTORY; i++){
			group->contents_3d[i] = (char**) malloc(group->num_regs*sizeof(char*));
		}
	}
	else{
		group->contents_4d = (char****) malloc(NUM_HISTORY*sizeof(char***));
		for(int i =0; i< NUM_HISTORY; i++){
			group->contents_4d[i] = (char***) malloc(group->num_entries*sizeof(char**));
			for(int k=0;k<group->num_entries;k++){
	  			group->contents_4d[i][k]     = (char**) malloc(group->num_regs*sizeof(char*));
		  }
		}
	}
}

//this initializes a ncurses window and sets up the arrays for exchanging reg information
extern "C" void initcurses(int in_scale, int num_prf_entries, int num_btb_lines, int num_rs_entries, int num_rob_entries, int num_adders,
	 					int num_branches, int num_mults, int num_mems, int load_queue_size, int store_queue_size, int rat_size){
  int nbytes;
  int ready_val;

  scale = in_scale;
  prf.num_entries = num_prf_entries;
  btb.num_entries = num_btb_lines;
  rs.num_entries = num_rs_entries;
  rob.num_entries = num_rob_entries;
  func_add.num_entries = num_adders;
  func_branch.num_entries = num_branches;
  func_mult.num_entries = num_mults;
  func_mem.num_entries = num_mems;
  lsq_load.num_entries = load_queue_size;
  lsq_store.num_entries = store_queue_size;
  rat.num_entries = rat_size;
  rrat.num_entries = rat_size;

  done_state = 0;
  echo_data = 1;

  pid_t childpid;
  pipe(readpipe);
  pipe(writepipe);
  stdout_save = dup(1);
  childpid = fork();
  if(childpid == 0){
    close(PARENT_WRITE);
    close(PARENT_READ);
    fp = fdopen(CHILD_READ, "r");
    fp2 = fopen("program.out","w");

    //allocate room on the heap for the reg data
	init_sig_group(&btb);
	init_sig_group(&rs);
	init_sig_group(&cdb);
	init_sig_group(&prf);

	init_sig_group(&func_add);
	init_sig_group(&func_mult);
	init_sig_group(&func_branch);
	init_sig_group(&func_mem);

	init_sig_group(&if0);
	init_sig_group(&if_id);
	init_sig_group(&id);
	init_sig_group(&id_ex);
	init_sig_group(&misc);

	init_sig_group(&rob);
	init_sig_group(&rob_signal);
	init_sig_group(&rob_misc);

	init_sig_group(&rat);
	init_sig_group(&rrat);

	init_sig_group(&lsq_load);
	init_sig_group(&lsq_store);
	init_sig_group(&lsq_in);

	inst_contents     = (char**) malloc(NUM_HISTORY*sizeof(char*));
    int i=0;
    timebuffer        = (char**) malloc(NUM_HISTORY*sizeof(char*));
    cycles            = (char**) malloc(NUM_HISTORY*sizeof(char*));
    clocks            = (char*) malloc(NUM_HISTORY*sizeof(char));
    resets            = (char*) malloc(NUM_HISTORY*sizeof(char));

    int j=0;
    for(;i<NUM_HISTORY;i++){
      timebuffer[i]       	= (char*) malloc(8);
      cycles[i]           	= (char*) malloc(7);
      inst_contents[i]    	= (char*) malloc(NUM_STAGES*10);

	  int k=0;
	  for(k=0;k<rat.num_entries;k++){
		  rat.contents_3d[i][k] 	= (char*) malloc(3*sizeof(char));
		  rrat.contents_3d[i][k] 	= (char*) malloc(3*sizeof(char));
	  }
    }
    setup_gui(fp);

    // Main loop for retrieving data and taking commands from user
    char quit_flag = 0;
    char resp=0;
    char running=0;
    int mem_addr=0;
    char goto_flag = 0;
    char cycle_flag = 0;
    char done_received = 0;
    memset(readbuffer,'\0',sizeof(readbuffer));
    while(!quit_flag){
      if (!done_received) {
        fgets(readbuffer, sizeof(readbuffer), fp);
        ready_val = processinput();
      }
      if(strcmp(readbuffer,"DONE") == 0) {
        done_received = 1;
        done_time = history_num - 1;
      }
      if(ready_val == 1 || done_received == 1){
        if(echo_data == 0 && done_received == 1) {
          running = 0;
          timeout(-1);
          echo_data = 1;
          history_num--;
          history_num%=NUM_HISTORY;
        }
        if(echo_data != 0){
          parsedata(history_num);
        }
        history_num++;
        // keep track of whether time wrapped around yet
        if (history_num == NUM_HISTORY)
          time_wrapped = 1;
        history_num%=NUM_HISTORY;

        //we're done reading the reg values for this iteration
        if (done_received != 1) {
          write(CHILD_WRITE, "n", 1);
          write(CHILD_WRITE, &mem_addr, 2);
        }
        char continue_flag = 0;
        int hist_num_temp = (history_num-1)%NUM_HISTORY;
        if (history_num==0) hist_num_temp = NUM_HISTORY-1;
        char echo_data_tmp,continue_flag_tmp;

        while(continue_flag == 0){
          resp=getch();
          if(running == 1){
            continue_flag = 1;
          }
          if(running == 0 || resp == 'p'){
            if(resp == 'n' && hist_num_temp == (history_num-1)%NUM_HISTORY){
              if (!done_received)
                continue_flag = 1;
            }else if(resp == 'n'){
              //forward in time, but not up to present yet
              hist_num_temp++;
              hist_num_temp%=NUM_HISTORY;
              parsedata(hist_num_temp);
		  } else if(resp == '1'){
			  switch_tabs(0);
		  } else if(resp == '2'){
			  switch_tabs(1);
		  } else if(resp == '3'){
			  switch_tabs(2);
		  } else if(resp == '4'){
			  switch_tabs(3);
		  } else if(resp == '5'){
			  switch_tabs(4);
		  } else if(resp == '6'){
			  switch_tabs(5);
			}else if(resp == 'r'){
              echo_data = 0;
              running = 1;
              timeout(0);
              continue_flag = 1;
            }else if(resp == 'p'){
              echo_data = 1;
              timeout(-1);
              running = 0;
              parsedata(hist_num_temp);
            }else if(resp == 'q'){
              //quit
              continue_flag = 1;
              quit_flag = 1;
            }else if(resp == 'b'){
              //We're goin BACK IN TIME, woohoo!
              // Make sure not to wrap around to NUM_HISTORY-1 if we don't have valid
              // data there (time_wrapped set to 1 when we wrap around to history 0)
              if (hist_num_temp > 0) {
                hist_num_temp--;
                parsedata(hist_num_temp);
              } else if (time_wrapped == 1) {
                hist_num_temp = NUM_HISTORY-1;
                parsedata(hist_num_temp);
              }
            }else if(resp == 'g' || resp == 'c'){
              // See if user wants to jump to clock cycle instead of sim time
              cycle_flag = (resp == 'c');

              // go to specified simulation time (either in history or
              // forward in simulation time).
              stop_time = get_time();

              // see if we already have that time in history
              int tmp_time;
              int cur_time;
              int delta;
              if (cycle_flag)
                sscanf(cycles[hist_num_temp], "%u", &cur_time);
              else
                sscanf(timebuffer[hist_num_temp], "%u", &cur_time);
              delta = (stop_time > cur_time) ? 1 : -1;
              if ((hist_num_temp+delta)%NUM_HISTORY != history_num) {
                tmp_time=hist_num_temp;
                i= (hist_num_temp+delta >= 0) ? (hist_num_temp+delta)%NUM_HISTORY : NUM_HISTORY-1;
                while (i!=history_num) {
                  if (cycle_flag)
                    sscanf(cycles[i], "%u", &cur_time);
                  else
                    sscanf(timebuffer[i], "%u", &cur_time);
                  if ((delta == 1 && cur_time >= stop_time) ||
                      (delta == -1 && cur_time <= stop_time)) {
                    hist_num_temp = i;
                    parsedata(hist_num_temp);
                    stop_time = 0;
                    break;
                  }

                  if ((i+delta) >=0)
                    i = (i+delta)%NUM_HISTORY;
                  else {
                    if (time_wrapped == 1)
                      i = NUM_HISTORY - 1;
                    else {
                      parsedata(hist_num_temp);
                      stop_time = 0;
                      break;
                    }
                  }
                }
              }

              // If we looked backwards in history and didn't find stop_time
              // then give up
              if (i==history_num && (delta == -1 || done_received == 1))
                stop_time = 0;

              // Set flags so that we run forward in the simulation until
              // it either ends, or we hit the desired time
              if (stop_time > 0) {
                // grab current values
                echo_data = 0;
                running = 1;
                timeout(0);
                continue_flag = 1;
                goto_flag = 1;
              }
            }
          }
        }
        // if we're instructed to goto specific time, see if we're there
        int cur_time=0;
        if (goto_flag==1) {
          if (cycle_flag)
            sscanf(cycles[hist_num_temp], "%u", &cur_time);
          else
            sscanf(timebuffer[hist_num_temp], "%u", &cur_time);
          if ((cur_time >= stop_time) ||
              (strcmp(readbuffer,"DONE")==0) ) {
            goto_flag = 0;
            echo_data = 1;
            running = 0;
            timeout(-1);
            continue_flag = 0;
            //parsedata(hist_num_temp);
          }
        }
      }
    }
    refresh();
    delwin(title_win);
    endwin();
    fflush(stdout);
    if(resp == 'q'){
      fclose(fp2);
      write(CHILD_WRITE, "Z", 1);
      exit(0);
    }
    readbuffer[0] = 0;
    while(strncmp(readbuffer,"DONE",4) != 0){
      if(fgets(readbuffer, sizeof(readbuffer), fp) != NULL)
        fputs(readbuffer, fp2);
    }
    fclose(fp2);
    fflush(stdout);
    write(CHILD_WRITE, "Z", 1);
    printf("Child Done Execution\n");
    exit(0);
  } else {
    close(CHILD_READ);
    close(CHILD_WRITE);
    dup2(PARENT_WRITE, 1);
    close(PARENT_WRITE);

  }
}


// Function to make testbench block until debugger is ready to proceed
extern "C" int waitforresponse(){
  static int mem_start = 0;
  char c=0;
  while(c!='n' && c!='Z') read(PARENT_READ,&c,1);
  if(c=='Z') exit(0);
  mem_start = read(PARENT_READ,&c,1);
  mem_start = mem_start << 8 + read(PARENT_READ,&c,1);
  return(mem_start);
}

extern "C" void flushpipe(){
  char c=0;
  read(PARENT_READ, &c, 1);
}

// Function to return string representation of opcode given inst encoding
char *get_opcode_str(int inst, int valid_inst)
{
  int opcode, check;
  char *str;

  if (valid_inst == ((int)'x' - (int)'0'))
    str = "-";
  else if(!valid_inst)
    str = "-";
  else if(inst==NOOP_INST)
    str = "nop";
  else {
    inst_t dummy_inst;
    dummy_inst.decode(inst);
    str = const_cast<char*>(dummy_inst.str); // due to legacy code..
  }

  return str;
}

// Function to parse register $display() from testbench and add to
// names/contents arrays
void parse_register(char *readbuf, int reg_num, char*** contents, char** reg_names) {
  char name_buf[32];
  char val_buf[32];
  int tmp_len;

  sscanf(readbuf,"%*c%s %d:%s",name_buf,&tmp_len,val_buf);
  int i=0;
  for (;i<NUM_HISTORY;i++){
    contents[i][reg_num] = (char*) malloc((tmp_len+1)*sizeof(char));
  }
  strcpy(contents[history_num][reg_num],val_buf);
  reg_names[reg_num] = (char*) malloc((strlen(name_buf)+1)*sizeof(char));
  strncpy(reg_names[reg_num], readbuf+1, strlen(name_buf));
  reg_names[reg_num][strlen(name_buf)] = '\0';
}

// Function to parse register $display() from testbench and add to
// names/contents arrays
void parse_register_superscaler(char *readbuf, int reg_num, char**** contents, char** reg_names, int width) {
  char name_buf[32];
  char val_buf[32];
  int pipe_idx;
  int tmp_len;

  sscanf(readbuf,"%*c%s %d:%d:%s",name_buf,&pipe_idx,&tmp_len,val_buf);
  int i=0;
  for (;i<NUM_HISTORY;i++){
	int j=0;
	for(;j<width;j++){
    	contents[i][j][reg_num] = (char*) malloc((tmp_len+1)*sizeof(char));
	}
  }
  strcpy(contents[history_num][pipe_idx][reg_num],val_buf);
  reg_names[reg_num] = (char*) malloc((strlen(name_buf)+1)*sizeof(char));
  strncpy(reg_names[reg_num], readbuf+1, strlen(name_buf));
  reg_names[reg_num][strlen(name_buf)] = '\0';
}

// Ask user for simulation time to stop at
// Since the enter key isn't detected, user must press 'g' key
//  when finished entering a number.
int get_time() {
  int col = COLS/2-6;
  wattron(title_win,A_REVERSE);
  mvwprintw(title_win,1,col,"goto time: ");
  wrefresh(title_win);
  int resp=0;
  int ptr = 0;
  char buf[32];
  int i;

  resp=wgetch(title_win);
  while(resp != 'g' && resp != KEY_ENTER && resp != ERR && ptr < 6) {
    if (isdigit((char)resp)) {
      waddch(title_win,(char)resp);
      wrefresh(title_win);
      buf[ptr++] = (char)resp;
    }
    resp=wgetch(title_win);
  }

  // Clean up title window
  wattroff(title_win,A_REVERSE);
  mvwprintw(title_win,1,col,"           ");
  for(i=0;i<ptr;i++)
    waddch(title_win,' ');

  wrefresh(title_win);

  buf[ptr] = '\0';
  return atoi(buf);
}
