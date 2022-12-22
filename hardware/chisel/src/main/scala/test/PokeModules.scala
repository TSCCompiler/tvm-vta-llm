/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
package vta.test

import Chisel.iotesters.PeekPokeTester
import vta.core.MAC

//class PokeModules(c: MAC) extends PeekPokeTester(c){
//
//  poke(c.io.a, -1);
//  poke(c.io.b, 7);
//  poke(c.io.c, 10);
//  step(1);
//  expect(c.io.y, 3);
//
//}

//class PokeMACApp extends App {
//  val arguments = Array(
//    "--backend-name", "treadle",
//    // "--backend-name", "vcs",
//    // "--is-verbose",
//    "--test-seed", "0"
//  )
//  chisel3.iotesters.Driver.execute(arguments, ()=>new MAC){
//    c=>new PokeModules(c)
//  }
//
//}
