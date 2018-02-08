# Introduction

Malware analysis rarely have the luxury of access to the source code of malicious programs when studying a piece of malware. Often, the malware executable itself is the only evidence they have available. However, it is possible to decompile the executable into its assembly instructions which in turn can yield more information on how a particular piece of malware works

Because many forms of malware today rely on connecting to a command and control (C&C) servers to obtain instructions, it is important to have an understanding of how the process of connecting, sending and receiving data looks like in assembly so that we can properly decipher these sections of code and correctly identify how the malware functions.

To develop our understanding of network operations in assembly, we developed a TCP/IP client application that communicates with a server. The server originally functions as simple echo server, however we modified it to also extract the IP address of any client that connects to it.

# Design

In order to implement the client and server, there were a few necessary functions we needed to implement in order to deliver all of the requirements. The following functions were required for us to implement: 

* _itoa(int x) - integer to ascii

* _atoi(char *c) - ascii to integer

* _ntohs(int x) and _htons(int x) 

    * Short int network - host byte order conversions

* _ntohl(int x) and _htonl(int x)

    * Long int network - host byte order conversions

**STOSB **

* Writes a byte from RAX → RDI register and automatically increment RDI

### **Integer to ASCII**

    RAX = Integer to convert

    RDI  = Address of the result



    Load the address of the buffer that will hold the resulting ascii into RDI

    Clear the RBX register, used as counter for stack pushes

    Check if RAX is less than 0 

    if less than 0 perform 2’s complement on RAX to make it positive

    Write a ‘-’ character to the buffer by using the STOSB instruction 
    (See STOSB description) 


    Divide RAX by 10. Result will be in RAX, remainder in RDX

    Add 0x30 to RDX to convert the remainder int => ascii

    Push the result to the stack

    Increment RBX (stack push counter)

    Check if the result, RAX is 0

    Repeat if not 0

    Loop while RBX (stack counter) > 0

      Pop result from stack to rax

      Write RAX to buffer using STOSB

    Write a line feed to the buffer to complete

    Return

### **ASCII to Integer**

    RDX = pointer to char array to convert

    RAX = Integer result



    Read one byte at a time from RDX → RCX

    Increment RDX to point to the next character 

    Check of RCX contains ‘-’ character

    If so, set the negative flag (use RDI as the negative flag) 

    Subtract 0x30 from RCX to convert the ascii character to an Integer

    Multiply RAX by 10 to get the RAX register ready for the integer

    ADD RCX to RAX 

    Repeat until invalid character is discovered 

    If the negative flag is set

    2’s complement RAX

    return 


	

### **Short Integer byte order conversion (16 bit)**

    Important instruction: Rotate

      Rotates the register by n bits left or right (rol ror)

      Bits that slide off the end are appended to the other side

    RAX = integer to flip byte order on

    RAX will also hold the result

    Short integer is only 16 bits. Only the lower 16 bits of RAX will be set for any given input

    In that case we will rotate left the AX register by 8 bits.

    The result is that the first 8 bits `````````````````````````will be swapped with the last 8 bits

    Byte order has been flipped

    Return 

	  Example: 2222 = 0x56ce = 0101 0110 1100 1110

    Shift left by 8 bits

    ← 0101 0110 1100 1110 

      1100 1110 0101 0110

      = 0xce56 

      Result is now in host byte order

### **Long Integer byte order conversion (32 bit)**

    RAX = integer to flip byte order on
    RAX will also hold the result

    Long integer is 32 bits, an IP address will be encoded in 32 bits.

    An ip address is made up of 4 octets, each 8 bits

    First we need to rotate the last 16 bits (AX) 8 bits left

    Then we will rotate the last 32 bits (EAX) 16 bits left
    Then we will again rotate the last 16 bits (AX) 8 bits left

    Example: 192.168.0.1

    Step 1: 192.168.0.1 

      ROL AX, 8 

      = 192.168.1.0

    Step 2: 192.168.1.0 

      ROL EAX, 16

      = 1.0.192.168

    Step 3: 1.0.192.168

      ROL AX, 8

      = 1.0.167.192

    We now have the host byte order

# Functions in Action: 

Value contained in &port before calling ATOI: 
![image alt text](/readme_images/image_0.png)

Result of ATOI function in EAX: 

![image alt text](/readme_images/image_1.png)

Result of NTOHS function:

![image alt text](/readme_images/image_2.png)

Value of  IP address 127.0.0.1 in hex prior to NTOHL:
![image alt text](/readme_images/image_3.png)

Value of the same IP address after call to NTOHL:

![image alt text](/readme_images/image_4.png)

# Testing

To test the application, VMware Player was used to set up two Fedora 27 virtual machines, one to act as the server and the other as the client. The server VM was configured with an IP address of 192.168.1.128. The client VM was configured with an IP of 192.168.1.117. Both VMs had the following software installed:

* **NASM version 2.13.02**

* **GDB version 8.0.1.33**

* **Visual Studio Code 1.19.2**

The source code for this assignment consists of the following files:

* **server.asm**

* **client.asm**

To compile and run the server, open a Terminal window and run the commands below in the following order:

    **nasm -f elf64 -o server.o server.asm**

    **ld server.o -o server**

    **./server**

The server will then prompt you to provide the port number to listen on for incoming connections.

To compile and run the client, open a Terminal window and run the commands below in the following order:

    **nasm -f elf64 -o client.o client.asm**

    **ld client.o -o client**

    **./client**

After running the client, you will be prompted for the port number and IP address of the server to connect to, along with the message and the number of times you want to send it to the server. 

## Test Cases

The following requirements were given for successful implementation of the client and server application:

1. The client application will get the server IP/Port and the number of messages to be sent from the user

2. The user will have the option of specifying other ports than the default (port 22222)

3. The client will print out the echoed strings together with the server IP

4. The server code will be modified to receive a series of messages from the client and print them out. In addition the server will also display the IP address of the client machine

Based on the requirements above, the following test cases were generated to test the application against. The results and discussion of each test case is presented in the proceeding sections.

<table>
  <tr>
    <td>#</td>
    <td>Scenario</td>
    <td>Expected Behavior</td>
    <td>Actual Behavior</td>
    <td>Status</td>
  </tr>
  <tr>
    <td>1</td>
    <td>Client is run, connecting to the default port of 22222 (Req 1)</td>
    <td>Client prompts user for the server IP, port, message to send and the number of times to send it</td>
    <td>Client prompts user for the server IP, por, message to send and the number of times to send it</td>
    <td>PASSED</td>
  </tr>
  <tr>
    <td>2</td>
    <td>Client is run, connecting to a non-default port (Req 2)</td>
    <td>Client connects to server running on a non default port</td>
    <td>Client connects to server running on a non default port</td>
    <td>PASSED</td>
  </tr>
  <tr>
    <td>3</td>
    <td>Client is run and sends a message to the server multiple times (Req 3)</td>
    <td>Client prints the message echoed back from the server along with the server IP address</td>
    <td>Client prints the message echoed back from the server along with the server IP address</td>
    <td>PASSED</td>
  </tr>
  <tr>
    <td>4</td>
    <td>Client is run and sends a message to the server multiple times (Req 4)</td>
    <td>Server prints out all messages sent by the client along with the client’s IP address</td>
    <td>Server prints out all messages sent by the client along with the client’s IP address</td>
    <td>PASSED</td>
  </tr>
</table>


## Test Case 1 - Client is run, connecting to the default port of 22222

For this test case, we start the server on port 22222:

![image alt text](/readme_images/image_5.png)

The client is then run with the input below:

![image alt text](/readme_images/image_6.png)

From the screenshots, we can see that the client prompts the user for the server IP, port number, message to send and the number of times to send the message so this test case passes.

## Test Case 2 - Client is run, connecting to a non-default port

For this test case, we start the server on port 31337:

![image alt text](/readme_images/image_7.png)

The client is then run with the input below:

![image alt text](/readme_images/image_8.png)

The client and server successfully connect and give us the output below:

![image alt text](/readme_images/image_9.png)

![image alt text](/readme_images/image_10.png)

From these screenshots, we can see that the client and server communicate successfully on a non-default port so we can conclude that this test case passes as well.

## Test Case 3 - Client is run and sends a message to the server multiple times

For this test case, the server is started on the default port of 22222 again. The client is configured to send multiple messages to the server using the settings in the screenshot below:

![image alt text](/readme_images/image_11.png)

The next screenshot shows the client printing the echoed message back from the server along with the server IP address as expected. As a result, we conclude that this test case passes.

![image alt text](/readme_images/image_12.png)

## Test Case 4 - Client is run and sends a message to the server multiple times (Req 4)

For this test case, the server is started on the default port of 22222. The client is configured to send multiple messages to the server using the settings in the screenshot below:

![image alt text](/readme_images/image_13.png)

The next screenshot shows the server printing the messages received from the client along with its IP address successfully. Based on these results, we conclude that this test case passes.

![image alt text](/readme_images/image_14.png)

# Conclusion

Since our test cases have verified that all requirements of this assignment are working properly, we can conclude that our implementation of the TCP/IP client and server in assembly was successful. Although it was challenging and frustrating at times, it was rewarding when we finally figured out the assembly instructions required to to establish a TCP/IP connection between computers using the various Linux syscalls. The knowledge gained from this assignment will valuable going forward in this course once we begin the task of analyzing malware samples.

