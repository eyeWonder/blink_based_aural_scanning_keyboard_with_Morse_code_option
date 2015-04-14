


// https://github.com/chester1000/MorseConverter/blob/master/src/pl/d30/Ex14_6/Morse.java
String toLetter(String s) {        
  switch(s) {
  case ".": 
    return "e";
  case "..": 
    return "i";
  case "...": 
    return "s";
  case "....": 
    return "h";
  case "...-": 
    return "v";
  case "..-": 
    return "u";
  case "..-.": 
    return "f";
  case ".-": 
    return "a";
  case ".-.": 
    return "r";
  case ".-..": 
    return "l";
  case ".--": 
    return "w";
  case ".--.": 
    return "p";
  case ".---": 
    return "j";
  case "-": 
    return "t";
  case "-.": 
    return "n";
  case "-..": 
    return "d";
  case "-...": 
    return "b";
  case "-..-": 
    return "x";
  case "-.-": 
    return "k";
  case "-.-.": 
    return "c";
  case "-.--": 
    return "y";
  case "--": 
    return "m";
  case "--.": 
    return "g";
  case "--..": 
    return "z";
  case "--.-": 
    return "q";
  case "---": 
    return "o";
  case ".....":
    return "5";
  case "...._":
    return "4";
  case "...__":
    return "3";
  case "..--..":
    return "?";
  case "..--.-":
    return "_";
  case "..___":
    return "2";
  case "._.._.":
    return "\"";
  case "._._.":
    return "+";
  case ".-.-._":
    return ".";
  case ".__._.":
    return "@";
  case ".____":
    return "1";  
  case ".____.":
    return "'";
  case "_....":
    return "6";
  case "_...._":
    return "-";
  case "_.._.":
    return "/";  
  case "_._._.":
    return ";";
  case "_._.__":
    return "!";
  case "__...":
    return "7";  
  case "__..__":
    return ",";
  case "___..":
    return "8";
  case "___...":
    return ":";  
  case "____.":
    return "9";
  case "_____":
    return "0";
  default: 
    return "";
  }
};
//*/
