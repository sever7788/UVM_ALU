`include "uvm_macros.svh"
package my_pkg;
import uvm_pkg::*;

`define N 4
`define M 4

class Item extends uvm_sequence_item;
  `uvm_object_utils(Item);
  
  rand bit [`N-1:0] A, B;
  rand bit [`M-1:0] instruction;
  logic [`N-1:0] ALU_out;
  logic [7:0] add_cnt;
  logic [7:0] a_eq_b_cnt;
  
  function string convert2string;
    return $sformatf("A=%d, B=%d, instruction=%d, ALU_out=%d, add_cnt=%d, a_eq_b_cnt=%d ", A, B, instruction, ALU_out, add_cnt, a_eq_b_cnt);
  endfunction

  function new(string name = "Item");
    super.new(name);
  endfunction

  
  
  constraint c_B {
    if(instruction[`M-1] == 0) B != 0;
  }
endclass

class gen_item_seq extends uvm_sequence;
  `uvm_object_utils(gen_item_seq)
  function new(string name="gen_item_seq");
    super.new(name);
    cg = new();
  endfunction
  
  Item m_item;
  rand int num; 	// Config total number of items to be sent
  
  covergroup cg;
    option.per_instance = 1;
    
    cp_A: coverpoint m_item.A;
    cp_B: coverpoint m_item.B;
    cp_instruction: coverpoint m_item.instruction;
 
  endgroup: cg

  virtual task body();
    while (cg.get_coverage < 100) begin
    	m_item = Item::type_id::create("m_item");
    	start_item(m_item);
    	m_item.randomize();
      	cg.sample();
      `uvm_info("SEQ", $sformatf("Generate new item: %s", m_item.convert2string()), UVM_HIGH)
      	finish_item(m_item);
    end
    `uvm_info("SEQ", $sformatf("Done generation of %0d items", num), UVM_LOW)
  endtask
endclass

class driver extends uvm_driver #(Item);
  `uvm_component_utils(driver)
  function new(string name = "driver", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual alu_if vif;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("DRV", "Could not get vif")
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    forever begin
      Item m_item;
      `uvm_info("DRV", $sformatf("Wait for item from sequencer"), UVM_HIGH)
      seq_item_port.get_next_item(m_item);
      drive_item(m_item);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive_item(Item m_item);
    @(posedge vif.clk);
    vif.A <= m_item.A;
    vif.B <= m_item.B;
    vif.instruction <= m_item.instruction;
  endtask
endclass

class monitor extends uvm_monitor;
  `uvm_component_utils(monitor)
  function new(string name="monitor", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  uvm_analysis_port  #(Item) mon_analysis_port;
  virtual alu_if vif;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("MON", "Could not get vif")
    mon_analysis_port = new ("mon_analysis_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    
    forever begin
      @ (posedge vif.clk);
      if (vif.rst) begin
        Item item = Item::type_id::create("item");
        item.A = vif.A;
        item.B = vif.B;
        item.instruction = vif.instruction;
        item.ALU_out = vif.ALU_out;
        item.add_cnt = vif.add_cnt;
        item.a_eq_b_cnt = vif.a_eq_b_cnt;
        mon_analysis_port.write(item);
        `uvm_info("MON", $sformatf("Saw item %s", item.convert2string()), UVM_HIGH)
      end
    end
  endtask
endclass    
    
class scoreboard extends uvm_scoreboard;
  `uvm_component_utils(scoreboard)
  function new(string name="scoreboard", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  logic [`N-1:0] exp_ALU_out;
  logic [7:0] exp_add_cnt;
  logic [7:0] exp_a_eq_b_cnt;

  uvm_analysis_imp #(Item, scoreboard) m_analysis_imp;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    m_analysis_imp = new("m_analysis_imp", this);
    exp_add_cnt = 0;
    exp_a_eq_b_cnt = 0;
    exp_ALU_out = 0;
    
  endfunction

  virtual function write(Item item);
    
    if (item.ALU_out == exp_ALU_out &&
	    item.add_cnt == exp_add_cnt &&
        item.a_eq_b_cnt == exp_a_eq_b_cnt
      ) begin
      `uvm_info("SCBD", $sformatf("PASS ! ALU_out=%0d exp_ALU_out=%0d, add_cnt=%0d exp_add_cnt=%0d, a_eq_b_cnt=%0d exp_a_eq_b_cnt=%0d", item.ALU_out, exp_ALU_out,item.add_cnt,exp_add_cnt,item.a_eq_b_cnt, exp_a_eq_b_cnt), UVM_LOW);
    end else begin
      `uvm_error("SCBD", $sformatf("ERROR ! ALU_out=%0d exp_ALU_out=%0d, add_cnt=%0d exp_add_cnt=%0d, a_eq_b_cnt=%0d exp_a_eq_b_cnt=%0d", item.ALU_out, exp_ALU_out,item.add_cnt,exp_add_cnt,item.a_eq_b_cnt, exp_a_eq_b_cnt), UVM_HIGH);
    end
    
    if(item.instruction[`M-1]) begin
      case (item.instruction[`M-2:0])
        3'h0: exp_ALU_out = item.A & item.B; 
        3'h1: exp_ALU_out = item.A | item.B; 
        3'h2: exp_ALU_out = item.A ^ item.B; 
        3'h3: exp_ALU_out = ~(item.A | item.B); 
        3'h4: exp_ALU_out = ~(item.A & item.B); 
        3'h5: exp_ALU_out = ~(item.A ^ item.B); 
        3'h6: exp_ALU_out = (item.A>item.B) ? 4'h1: 4'h0;
        3'h7: begin 
          exp_ALU_out = (item.A==item.B) ? 4'h1: 4'h0;
          exp_a_eq_b_cnt = exp_a_eq_b_cnt + 1;
        end
        default: exp_ALU_out = item.A;
      endcase
    end else begin
      case (item.instruction[`M-2:0])
        3'h0: begin 
          exp_ALU_out = item.A + item.B; 
          exp_add_cnt = exp_add_cnt + 1;
        end
        3'h1: exp_ALU_out = item.A - item.B; 
        3'h2: exp_ALU_out = item.A * item.B; 
        3'h3: exp_ALU_out = item.A / item.B; 
        3'h4: exp_ALU_out = item.A << 1; 
        3'h5: exp_ALU_out = item.A >> 1; 
        3'h6: exp_ALU_out = {item.A[`N-2:0], item.A[`N-1]};
        3'h7: exp_ALU_out = {item.A[0], item.A[`N-1:1]}; 
        default: exp_ALU_out = item.A;
      endcase
    end
  endfunction
endclass    

class agent extends uvm_agent;
  `uvm_component_utils(agent)
  function new(string name="agent", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  driver 		d0; 		// Driver handle
  monitor 		m0; 		// Monitor handle
  uvm_sequencer #(Item)	s0; 		// Sequencer Handle

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    s0 = uvm_sequencer#(Item)::type_id::create("s0", this);
    d0 = driver::type_id::create("d0", this);
    m0 = monitor::type_id::create("m0", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    d0.seq_item_port.connect(s0.seq_item_export);
  endfunction

endclass

class env extends uvm_env;
  `uvm_component_utils(env)
  function new(string name="env", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  agent 		a0; 		// Agent handle
  scoreboard	sb0; 		// Scoreboard handle

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a0 = agent::type_id::create("a0", this);
    sb0 = scoreboard::type_id::create("sb0", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    a0.m0.mon_analysis_port.connect(sb0.m_analysis_imp);
  endfunction
endclass
    
class base_test extends uvm_test;
  `uvm_component_utils(base_test)
  function new(string name = "base_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  env  				e0;
  gen_item_seq 		seq;
  virtual  	alu_if 	vif;

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create the environment
    e0 = env::type_id::create("e0", this);

    // Get virtual IF handle from top level and pass it to everything
    // in env level
    if (!uvm_config_db#(virtual alu_if)::get(this, "", "alu_vif", vif))
      `uvm_fatal("TEST", "Did not get vif")
      uvm_config_db#(virtual alu_if)::set(this, "e0.a0.*", "alu_vif", vif);

    // Create sequence and randomize it
    seq = gen_item_seq::type_id::create("seq");
    seq.randomize();
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    apply_reset();
    seq.start(e0.a0.s0);							
    phase.drop_objection(this);
  endtask

  virtual task apply_reset();
    vif.rst <= 0;
    vif.A <= 0;
    vif.B <= 0;
    vif.instruction <= 0;
   @ (posedge vif.clk);
    vif.rst <= 1;
     
  endtask 
endclass

class test_1 extends base_test;
  `uvm_component_utils(test_1)
  function new(string name="test_1", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
endclass    
endpackage: my_pkg

module top;
  
  import uvm_pkg::*;
  import my_pkg::*;
  
  alu_if _if ();

  ALU alu ( .clk(_if.clk),
           .rst(_if.rst),
             .A(_if.A),
             .B(_if.B),
             .instruction(_if.instruction),
             .ALU_out(_if.ALU_out),
             .add_cnt(_if.add_cnt),
             .a_eq_b_cnt(_if.a_eq_b_cnt)
            );
	
  initial begin
    $dumpfile("top.vcd");
    $dumpvars(0, top);
    
    _if.clk = 1;
    forever #10 _if.clk = ~_if.clk;
  end
  
  initial begin
    uvm_config_db #(virtual alu_if)::set(null, "uvm_test_top", "alu_vif", _if);
     
    run_test("test_1");
    
  end
endmodule